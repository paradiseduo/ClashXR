<h1 align="center">
  <img src="https://github.com/Dreamacro/clash/raw/master/docs/logo.png" alt="Clash" width="200">
  <br>
  ClashXR
  <br>
</h1>

## Since the native clash core already supports the SSR protocol, this project will stop maintenance from now on, thank you for your support all the way ❤️

A rule based proxy For Mac base on [Clashr](https://github.com/paradiseduo/clashr)(support chacha20).

Based on [clashX](https://github.com/yichengchen/clashX)

You can do [this](https://github.com/paradiseduo/subweb) to use ClashXR.


## Features

- HTTP/HTTPS and SOCKS protocol
- Surge like configuration
- GeoIP rule support
- Support Vmess/Shadowsocks/ShadowsocksR/Socks5/Torjan
- Support for Netfilter TCP redirect

## Install

You can download from [release](https://github.com/paradiseduo/ClashXR/releases) page， or use homebrew
```
brew cask install clashxr
```

## Build
- Make sure have python3 and golang installed in your computer.

- Download deps
  ```
  bash install_dependency.sh
  ```
- Build
  
- Signature check
  ```shell 
  ./SMJobBlessUtil.py setreq /path/to/ClashXR.app ClashXR/Info.plist ProxyConfigHelper/Helper-Info.plist
  ```

- Build and run.

## Config


The default configuration directory is `$HOME/.config/clash`

The default name of the configuration file is `config.yaml`. You can use your custom config name and switch config in menu `Config` section.

To Change the ports of ClashX, you need to modify the `config.yaml` file. The `General` section settings in your custom config file would be ignored.

Checkout [Clash](https://github.com/Dreamacro/clash) or [SS-Rule-Snippet for Clash](https://github.com/Hackl0us/SS-Rule-Snippet/blob/master/LAZY_RULES/clash.yaml) for more detail.

## Advance Config
### Change your status menu icon

  Place your icon file in the `~/.config/clash/menuImage.png`  then restart ClashX

### Change default system ignore list.

- Download sample plist in the [Here](proxyIgnoreList.plist) and place in the

  ```
  ~/.config/clash/proxyIgnoreList.plist
  ```

- Edit the `proxyIgnoreList.plist` to set up your own proxy ignore list

### Use url scheme to import remote config.

- Using url scheme describe below

  ```
  clash://install-config?url=http%3A%2F%2Fexample.com&name=example
  ```


## Star Trend
[![Stargazers over time](https://starchart.cc/paradiseduo/ClashXR.svg)](https://starchart.cc/paradiseduo/ClashXR)
