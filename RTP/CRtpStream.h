#ifndef __RTP_STREAM_H__
#define __RTP_STREAM_H__

#include <cstdint>
#include <cstdlib>
#include <memory>
#include <array>

const int maxRtpMtu = 1500;
const int maxPktMtu = 1400;

class CRtpStream;
typedef void CRtpStreamOutCallback(void *callbackRefCon, const uint8_t *data, int length);

class CRtpStream {
    
public:
    CRtpStream(CRtpStreamOutCallback* callback, void *callbackRefCon): mCallback(callback), mCallbackRef(callbackRefCon) {}
    ~CRtpStream() {}
    
    int streamOut(const uint8_t* data, int length,  uint32_t timestamp);
    
private:
    CRtpStreamOutCallback* mCallback;
    void *mCallbackRef;
    uint8_t mOutbuf[::maxRtpMtu];
};

#endif
