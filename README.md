Carrier Demo
============

Carrier Demo is a demo application to show what can do over carrier network. It shows you can use this app to control each other via NAT traversal.

## Feaures:

The items for remote control currently includes:

- Turn on/off torch (or light)
- Turn on/off ringtone
- Increase/Decrease ringtone volume
- Turn on/off camera video

## Build from source

You should get source code from the following repository on github.com:

```shell
$ git clone https://github.com/stiartsly/CarrierDemo.git
$ cd CarrierDemo
$ open -a Xcode CarrierDemo.xcworkspace
```
Then you can use Apple Xcode to build it.

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

