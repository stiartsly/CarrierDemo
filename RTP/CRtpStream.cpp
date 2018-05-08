#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <arpa/inet.h>
#include "CRtpStream.h"

struct RtpFixHeader {
    uint8_t csrcLen:4;
    uint8_t extension:1;
    uint8_t padding:1;
    uint8_t version:2;
    
    uint8_t payload:7;
    uint8_t marker:1;
    
    uint16_t seqNo;
    uint32_t timestamp;
    uint32_t ssrc;
};

struct RtpNaluHeader {
    uint8_t nal_unit_type:5;
    uint8_t nal_rfc_idsc:2;
    uint8_t forbidden_bit:1;
};

struct RtpFuIndicator {
    uint8_t nal_unit_type:5;
    uint8_t nal_rfc_idsc:2;
    uint8_t forbidden_bit:1;
};

struct RtpFuHeader {
    uint8_t type:5;
    uint8_t r:1;
    uint8_t e:1;
    uint8_t s:1;
};

namespace nalu {

    struct NaluUnit {
        int length;
        int forbidden_bit;
        int nal_rfc_idsc;
        int nal_unit_type;
        uint8_t* data;
    };
    
#define CHECK_NALU(data, idx) ((data[idx++] == 0x00) && \
(data[idx++] == 0x00) && \
(data[idx++] == 0x00) && \
(data[idx++] == 0x01))
    
    int readNalu(const uint8_t* data, int length, int offset, nalu::NaluUnit& nalu)
    {
        int i = offset;
        int j = 0;
        
        while(i < length) {
            if (CHECK_NALU(data, i)) {
                nalu.data = (uint8_t*)&data[i];
                nalu.forbidden_bit = nalu.data[0] & 0x80; // highest bit;
                nalu.nal_rfc_idsc  = nalu.data[0] & 0x60; // 2 bits
                nalu.nal_unit_type = nalu.data[0] & 0x1f; // low 5 bits.

                if (nalu.nal_unit_type == 5 || nalu.nal_unit_type == 1) {
                    nalu.length = length - i;
                }
                else {
                    j = i;
                    while(j < length) {
                        if (CHECK_NALU(data, j))
                            break;
                    }

                    if (j < length)
                        j -= 4; // find nalu, then rollback sizeof NALU size.

                    nalu.length = (j - i);
                }

                return (i - offset + nalu.length);
            }
        }
        return 0;
    }
}

int CRtpStream::streamOut(const uint8_t* data, int length,  uint32_t timestamp)
{
    static uint16_t seqNo = 0;
    nalu::NaluUnit nalu;
    uint8_t* payload = NULL;
    int len = 0;
    int off = 0;
    
    while((len = nalu::readNalu(data, length, off, nalu)) > 0) {
        memset(mOutbuf, 0, ::maxPktMtu);
        
        int sz = 0;
        RtpFixHeader* hdr = (RtpFixHeader*)&mOutbuf[sz];
        hdr->payload = 96; // h264;
        hdr->version = 2;
        hdr->seqNo   = htons(++seqNo);
        hdr->ssrc    = htonl(10);
        hdr->timestamp = htonl(timestamp);
        
        if (nalu.length <= ::maxPktMtu) { // All in one package.
            hdr->marker = 1;
            sz += sizeof(*hdr);
            
            RtpNaluHeader* nh = (RtpNaluHeader*)&mOutbuf[sz];
            nh->forbidden_bit = nalu.forbidden_bit;
            nh->nal_rfc_idsc  = nalu.nal_rfc_idsc >> 5; //?
            nh->nal_unit_type = nalu.nal_unit_type;
            sz += sizeof(*nh);
            
            payload = (uint8_t*)&mOutbuf[sz];
            memcpy(payload, nalu.data + 1, nalu.length - 1); //wierd.
            sz += nalu.length -1;
            
            mCallback(mCallbackRef, mOutbuf, sz);
            
            off += len;
            continue;
        }
        
        //Divide to serveral packages.
        
        int pktNum  = nalu.length / ::maxPktMtu;
        int pktLast = nalu.length % ::maxPktMtu;
        int idx = 0;
        
        // First package in thread of packages.
        sz = 0;
        hdr->marker = 0;
        sz += sizeof(*hdr);
        
        RtpFuIndicator* fui = (RtpFuIndicator*)&mOutbuf[sz];
        fui->forbidden_bit = nalu.forbidden_bit;
        fui->nal_rfc_idsc  = nalu.nal_rfc_idsc >> 5;
        fui->nal_unit_type = 28;
        sz += sizeof(*fui);
        
        RtpFuHeader* fuh = (RtpFuHeader*)&mOutbuf[sz];
        fuh->e = 0;
        fuh->r = 0;
        fuh->s = 1;
        fuh->type = nalu.nal_unit_type;
        sz += sizeof(*fuh);
        
        payload = (uint8_t*)&mOutbuf[sz];
        memcpy(payload, nalu.data + 1, ::maxPktMtu -1);
        sz += ::maxPktMtu -1;
        
        mCallback(mCallbackRef, mOutbuf, sz);
        idx++;
        
        // The middle packages.
        while(idx < pktNum) {
            sz = 0;
            hdr->marker = 0;
            hdr->seqNo  = htons(++seqNo);
            sz += sizeof(*hdr);
            
            /* same rtpFuIndicator */
            sz += sizeof(*fui);
            
            fuh->e = 0;
            fuh->r = 0;
            fuh->s = 0;
            fuh->type = nalu.nal_unit_type;
            sz += sizeof(*fuh);
            
            payload = (uint8_t*)&mOutbuf[sz];
            memcpy(payload, nalu.data + idx*::maxPktMtu, ::maxPktMtu);
            sz += ::maxPktMtu;
            
            mCallback(mCallbackRef, mOutbuf, sz);
            idx++;
        }
        
        if (pktLast) {
            /* the last package */
            sz = 0;
            hdr->marker = 1;
            hdr->seqNo  = htons(++seqNo);
            sz += sizeof(*hdr);
            
            /* same rtpFuIndicator*/
            sz += sizeof(*fui);
            
            fuh->r = 0;
            fuh->s = 0;
            fuh->e = 1;
            fuh->type = nalu.nal_unit_type;
            sz += sizeof(*fuh);
            
            payload = (uint8_t*)&mOutbuf[sz];
            memcpy(payload, nalu.data + idx*::maxPktMtu, pktLast);
            sz += pktLast;
            
            mCallback(mCallbackRef, mOutbuf, sz);
        }
        
        off += len;
    }
    return 0;
}
