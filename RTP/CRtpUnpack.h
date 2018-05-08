//
//  CRtpUnpack
#ifndef __RTP_UNPACK_H__
#define __RTP_UNPACK_H__


class CRtpUnpack
{

#define RTP_VERSION 2
#define BUF_SIZE (1024 * 1024)
    
    typedef struct
    {
        //LITTLE_ENDIAN
        unsigned short   cc:4;      /* CSRC count                 */
        unsigned short   x:1;       /* header extension flag      */
        unsigned short   p:1;       /* padding flag               */
        unsigned short   v:2;       /* packet type                */
        unsigned short   pt:7;      /* payload type               */
        unsigned short   m:1;       /* marker bit                 */
        
        unsigned short   seq;      /* sequence number            */
        unsigned int     ts;       /* timestamp                  */
        unsigned int     ssrc;     /* synchronization source     */
    } rtp_hdr_t;
    
public:
    
    CRtpUnpack ( int &error, unsigned char H264PAYLOADTYPE = 96 )
    : m_bSPSFound(false)
    , m_bWaitKeyFrame(true)
    , m_bPrevFrameEnd(false)
    , m_bAssemblingFrame(false)
    , m_wSeq(1234)
    , m_ssrc(0)
    {
        m_pBuf = new unsigned char[BUF_SIZE] ;
        if ( m_pBuf == NULL )
        {
            error = 1 ;
            return ;
        }
        
        m_H264PAYLOADTYPE = H264PAYLOADTYPE ;
        m_pEnd = m_pBuf + BUF_SIZE ;
        m_pStart = m_pBuf ;
        m_dwSize = 0 ;
        error = 0 ;
    }
    
    ~CRtpUnpack(void)
    {
        delete [] m_pBuf;
    }
    
    //pBuf为H264 RTP视频数据包，nSize为RTP视频数据包字节长度，outSize为输出视频数据帧字节长度。
    //返回值为指向视频数据帧的指针。输入数据可能被破坏。
    unsigned char* Parse_RTP_Packet(unsigned char *pBuf, unsigned short nSize, unsigned int *outSize, unsigned int *timestamp)
    {
        if ( nSize <= 12 )
        {
            return NULL ;
        }
        
        unsigned char *cp = (unsigned char*)&m_RTP_Header;
        cp[0] = pBuf[0] ;
        cp[1] = pBuf[1] ;
        
        m_RTP_Header.seq = pBuf[2] ;
        m_RTP_Header.seq <<= 8 ;
        m_RTP_Header.seq |= pBuf[3] ;
        
        m_RTP_Header.ts = pBuf[4] ;
        m_RTP_Header.ts <<= 8 ;
        m_RTP_Header.ts |= pBuf[5] ;
        m_RTP_Header.ts <<= 8 ;
        m_RTP_Header.ts |= pBuf[6] ;
        m_RTP_Header.ts <<= 8 ;
        m_RTP_Header.ts |= pBuf[7] ;
        
        m_RTP_Header.ssrc = pBuf[8] ;
        m_RTP_Header.ssrc <<= 8 ;
        m_RTP_Header.ssrc |= pBuf[9] ;
        m_RTP_Header.ssrc <<= 8 ;
        m_RTP_Header.ssrc |= pBuf[10] ;
        m_RTP_Header.ssrc <<= 8 ;
        m_RTP_Header.ssrc |= pBuf[11] ;
        
        unsigned char *pPayload = pBuf + 12 ;
        unsigned short PayloadSize = nSize - 12 ;
        
        // Check the RTP version number (it should be 2):
        if ( m_RTP_Header.v != RTP_VERSION )
        {
            return NULL ;
        }
        
        /*
         // Skip over any CSRC identifiers in the header:
         if ( m_RTP_Header.cc )
         {
         long cc = m_RTP_Header.cc * 4 ;
         if ( Size < cc )
         {
         return NULL ;
         }
         
         Size -= cc ;
         p += cc ;
         }
         
         // Check for (& ignore) any RTP header extension
         if ( m_RTP_Header.x )
         {
         if ( Size < 4 )
         {
         return NULL ;
         }
         
         Size -= 4 ;
         p += 2 ;
         long l = p[0] ;
         l <<= 8 ;
         l |= p[1] ;
         p += 2 ;
         l *= 4 ;
         if ( Size < l ) ;
         {
         return NULL ;
         }
         Size -= l ;
         p += l ;
         }
         
         // Discard any padding bytes:
         if ( m_RTP_Header.p )
         {
         if ( Size == 0 )
         {
         return NULL ;
         }
         long Padding = p[Size-1] ;
         if ( Size < Padding )
         {
         return NULL ;
         }
         Size -= Padding ;
         }*/
        
        // Check the Payload Type.
        if ( m_RTP_Header.pt != m_H264PAYLOADTYPE )
        {
            return NULL ;
        }
        
        int PayloadType = pPayload[0] & 0x1f ;
        int NALType = PayloadType ;
        if ( NALType == 28 ) // FU_A
        {
            if ( PayloadSize < 2 )
            {
                return NULL ;
            }
            
            NALType = pPayload[1] & 0x1f ;
        }
        
        if ( m_ssrc != m_RTP_Header.ssrc )
        {
            NSLog(@"CRtpUnpack, ssrc = %d", m_RTP_Header.ssrc);
            m_ssrc = m_RTP_Header.ssrc ;
            SetLostPacket () ;
        }
        
        if ( NALType == 0x07 ) // SPS
        {
            m_bSPSFound = true ;
        }
        
        if ( !m_bSPSFound )
        {
            return NULL ;
        }
        
        if ( NALType == 0x07 || NALType == 0x08 ) // SPS PPS
        {
            m_wSeq = m_RTP_Header.seq ;
            m_bPrevFrameEnd = true ;
            
            pPayload -= 4 ;
            *((unsigned int*)(pPayload)) = 0x01000000 ;
            *outSize = PayloadSize + 4 ;
            *timestamp = m_RTP_Header.ts ;
            return pPayload ;
        }
        
        if ( m_bWaitKeyFrame )
        {
            if ( m_RTP_Header.m ) // frame end
            {
                m_bPrevFrameEnd = true ;
                if ( !m_bAssemblingFrame )
                {
                    m_wSeq = m_RTP_Header.seq ;
                    return NULL ;
                }
            }
            
            if ( !m_bPrevFrameEnd )
            {
                m_wSeq = m_RTP_Header.seq ;
                return NULL ;
            }
            else
            {
                if ( NALType != 0x05 ) // KEY FRAME
                {
                    m_wSeq = m_RTP_Header.seq ;
                    m_bPrevFrameEnd = false ;
                    return NULL ;
                }
            }
        }
        
        
        ///////////////////////////////////////////////////////////////
        
        if ( m_RTP_Header.seq != (unsigned short)( m_wSeq + 1 ) ) // lost packet
        {
            NSLog(@"CRtpUnpack, LostPacket ............... expected seq = %d, seq = %d", m_wSeq + 1, m_RTP_Header.seq);
            m_wSeq = m_RTP_Header.seq ;
            SetLostPacket () ;
            return NULL ;
        }
        else
        {
            // 码流正常
            
            m_wSeq = m_RTP_Header.seq ;
            m_bAssemblingFrame = true ;
            
            if ( PayloadType != 28 ) // whole NAL
            {
                *((unsigned int*)(m_pStart)) = 0x01000000 ;
                m_pStart += 4 ;
                m_dwSize += 4 ;
            }
            else // FU_A
            {
                if ( pPayload[1] & 0x80 ) // FU_A start
                {
                    *((unsigned int*)(m_pStart)) = 0x01000000 ;
                    m_pStart += 4 ;
                    m_dwSize += 4 ;
                    
                    pPayload[1] = ( pPayload[0] & 0xE0 ) | NALType ;
                    
                    pPayload += 1 ;
                    PayloadSize -= 1 ;
                }
                else
                {
                    pPayload += 2 ;
                    PayloadSize -= 2 ;
                }
            }
            
            if ( m_pStart + PayloadSize < m_pEnd )
            {
                memcpy ( m_pStart, pPayload, PayloadSize ) ;
                m_dwSize += PayloadSize ;
                m_pStart += PayloadSize ;
            }
            else // memory overflow
            {
                NSLog(@"CRtpUnpack, LostPacket ............... memory overflow");
                SetLostPacket () ;
                return NULL ;
            }
            
            if ( m_RTP_Header.m ) // frame end
            {
                *outSize = m_dwSize ;
                *timestamp = m_RTP_Header.ts ;
                
                m_pStart = m_pBuf ;
                m_dwSize = 0 ;
                
                if ( NALType == 0x05 ) // KEY FRAME
                {
                    m_bWaitKeyFrame = false ;
                }
                return m_pBuf ;
            }
            else
            {
                return NULL ;
            }
        }
    }
    
    void SetLostPacket()
    {
        m_bSPSFound = false ;
        m_bWaitKeyFrame = true ;
        m_bPrevFrameEnd = false ;
        m_bAssemblingFrame = false ;
        m_pStart = m_pBuf ;
        m_dwSize = 0 ;
    }
    
private:
    rtp_hdr_t m_RTP_Header ;
    
    unsigned char *m_pBuf ;
    
    bool m_bSPSFound ;
    bool m_bWaitKeyFrame ;
    bool m_bAssemblingFrame ;
    bool m_bPrevFrameEnd ;
    unsigned char *m_pStart ;
    unsigned char *m_pEnd ;
    unsigned int m_dwSize ;
    
    unsigned short m_wSeq ;
    
    unsigned char m_H264PAYLOADTYPE ;
    unsigned int m_ssrc ;
};

#endif
