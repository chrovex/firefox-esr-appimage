#!/usr/bin/env bash

APP=firefox

# TEMPORARY DIRECTORY
mkdir -p tmp
cd ./tmp || exit 1

# DOWNLOAD APPIMAGETOOL
if ! test -f ./appimagetool; then
	wget -q https://github.com/pkgforge-dev/appimagetool-uruntime/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool || exit 1
	chmod a+x ./appimagetool
fi
export URUNTIME_PRELOAD=1

# CREATE FIREFOX BROWSER APPIMAGES

LAUNCHER="[Desktop Entry]
Version=1.0
Name=Firefox
GenericName=Web Browser
GenericName[zh_CN]=网络浏览器
GenericName[zh_TW]=網路瀏覽器
Comment=Browse the World Wide Web
Comment[zh_CN]=浏览互联网
Comment[zh_TW]=瀏覽網際網路
Keywords=Internet;WWW;Browser;Web;Explorer;
Keywords[zh_CN]=Internet;WWW;Browser;Web;Explorer;网页;浏览;上网;火狐;Firefox;ff;互联网;网站;;
Keywords[zh_TW]=Internet;WWW;Browser;Web;Explorer;網際網路;網路;瀏覽器;上網;網頁;火狐;
Exec=firefox %u
Icon=firefox
Terminal=false
X-MultipleArgs=false
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;application/x-xpinstall;application/pdf;application/json;
StartupNotify=true
StartupWMClass=firefox
Categories=Network;WebBrowser;
Actions=new-window;new-private-window;

[Desktop Action new-window]
Name=New Window
Name[zh_CN]=新建窗口
Name[zh_TW]=開新視窗
Exec=firefox --new-window %u

[Desktop Action new-private-window]
Name=New Private Window
Name[zh_CN]=新建隐私浏览窗口
Name[zh_TW]=新增隱私視窗
Exec=firefox --private-window %u"

_create_firefox_appimage() {
	# Detect the channel
	if [ "$CHANNEL" != stable ]; then
		DOWNLOAD_URL="https://download-installer.cdn.mozilla.net/pub/firefox/releases/140.1.0esr/linux-x86_64/en-US/firefox-140.1.0esr.tar.xz"
	else
		DOWNLOAD_URL="https://download.mozilla.org/?product=$APP-latest&os=linux64"
	fi

	# Download with wget or wget2
	if wget --version | head -1 | grep -q ' 1.'; then
		wget -q --no-verbose --show-progress --progress=bar "$DOWNLOAD_URL" --trust-server-names || exit 1
	else
		wget "$DOWNLOAD_URL" --trust-server-names || exit 1
	fi

	# Disable automatic updates
	#mkdir -p "$APP".AppDir && touch "$APP".AppDir/is_packaged_app || exit 1
	mkdir -p "$APP".AppDir/distribution
	cat <<-'HEREDOC' >> "$APP".AppDir/distribution/policies.json
	{
	  "policies": {
	    "DisableAppUpdate": true
	  }
	}
	HEREDOC

	# Extract the archive
	[ -e ./*tar.* ] && tar fx ./*tar.* && mv ./firefox/* "$APP".AppDir/ && rm -f ./*tar.* || exit 1

	# Enter the AppDir
	cd "$APP".AppDir || exit 1

	# Add the launcher and patch it depending on the release channel
	echo "$LAUNCHER" > firefox.desktop
	if [ "$CHANNEL" != stable ]; then
		sed -i "s/Name=Firefox/Name=Firefox ${CHANNEL^}/g; s/StartupWMClass=firefox/StartupWMClass=firefox-$CHANNEL/g" firefox.desktop
	fi

	# Add the icon
	cp ./browser/chrome/icons/default/default128.png firefox.png
	cd .. || exit 1

	# Check the version
	VERSION=$(cat ./"$APP".AppDir/application.ini | grep "^Version=" | head -1 | cut -c 9-)

	# Create te AppRun
	cat <<-'HEREDOC' >> ./"$APP".AppDir/AppRun
	#!/bin/sh
	HERE="$(dirname "$(readlink -f "${0}")")"
	export PATH="${HERE}:${PATH}"
	export MOZ_LEGACY_PROFILES=1
	export MOZ_APP_LAUNCHER="${APPIMAGE}"
	exec "${HERE}"/firefox "$@"
	HEREDOC
	chmod a+x ./"$APP".AppDir/AppRun

	# Export the AppDir to an AppImage
	ARCH=x86_64 ./appimagetool -u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|Firefox-appimage|continuous-$CHANNEL|*-$CHANNEL-*x86_64.AppImage.zsync" \
		--comp zstd ./"$APP".AppDir Firefox-"$CHANNEL"-"$VERSION"-x86_64.AppImage || exit 1
}

CHANNEL="stable"
mkdir -p "$CHANNEL" && cp ./appimagetool ./"$CHANNEL"/appimagetool && cd "$CHANNEL" || exit 1
_create_firefox_appimage
cd .. || exit 1
mv ./"$CHANNEL"/*.AppImage* ./

CHANNEL="esr"
mkdir -p "$CHANNEL" && cp ./appimagetool ./"$CHANNEL"/appimagetool && cd "$CHANNEL" || exit 1
_create_firefox_appimage
cd .. || exit 1
mv ./"$CHANNEL"/*.AppImage* ./

cd ..
mv ./tmp/*.AppImage* ./
