Carrier Demo
===========================

Carrier Demo is an application to show what can do over carrier network. It shows you can use App to control each other with p2p technology.

## Feaures:

The items for remote control currently includes:

- Turn on/off torch (or light)
- Turn on/off ringtone
- Increase/Decrease ringtone volume
- Turn on/off camera video

## Build from source

You should get source code from the following repository on github.com:

```
https://github.com/stiartsly/CarrierDemo.git
```
Then open this xcode project with Apple xcode to build it.

## Build dependencies

Before buiding app, you have to download and build the following dependencies:

- ElastosCarrier.framework
- ffmpeg
- QRCode

As to QRcode, you need to use following command to install and build distrbution

```shell
$ sudo gem install cocoapods  
$ pod install
```

## Deploy && Run

Run on Phone with iOS version 9.0 or higher.

## License

MIT

