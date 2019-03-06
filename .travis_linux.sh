#!/bin/bash
project_dir=$(pwd)

# Complain when not in Travis environment
if [ -z ${TRAVIS_COMMIT+x} ]; then
    echo "This script is intended to be used only in Travis CI environment."
    echo "To build VNote from source, please see the [documentation](https://tamlok.github.io/vnote/en_us/#!docs/Developers/Build%20VNote.md)."
    exit 1
fi

# Install qt5ct for a native look
sudo add-apt-repository ppa:hda-me/qt5ct -y

# Install qt5.9
sudo add-apt-repository ppa:george-edison55/cmake-3.x -y
sudo add-apt-repository ppa:beineri/opt-qt597-trusty -y
sudo apt-get update -qq
sudo apt-get -y install qt59base qt59webengine qt59webchannel qt59svg qt59location qt59tools qt59translations
source /opt/qt*/bin/qt*-env.sh

# Install qt5ct for a native look
sudo apt-get -y install qt5ct

tree /usr/lib/x86_64-linux-gnu/qt5/plugins

sudo cp -r -n /usr/lib/x86_64-linux-gnu/qt5/plugins/platformthemes /opt/qt*/plugins/

tree /opt/qt*/plugins/

# Compile newer version fcitx-qt5
sudo apt-get -y install fcitx-libs-dev libgl1-mesa-dev bison
sudo apt-get -y install cmake

wget http://xkbcommon.org/download/libxkbcommon-0.5.0.tar.xz
tar xf libxkbcommon-0.5.0.tar.xz
cd libxkbcommon-0.5.0
./configure -prefix=/usr -libdir=/usr/lib/x86_64-linux-gnu -disable-x11
make -j$(nproc) && sudo make install

git clone git://anongit.kde.org/extra-cmake-modules
cd extra-cmake-modules
mkdir build && cd build
cmake ..
make -j$(nproc) && sudo make install

git clone https://github.com/fcitx/fcitx-qt5
cd fcitx-qt5
git checkout 1.0.5
cmake .
make -j$(nproc) && sudo make install

# Copy fcitx-qt5 files to qt
sudo cp /usr/local/lib/libFcitxQt5DBusAddons.so* /opt/qt*/lib/
sudo cp /usr/local/lib/libFcitxQt5WidgetsAddons.so* /opt/qt*/lib/

tree /opt/qt59/lib/

set -x
# Compile xcb-imdkit for fcitx5
git clone https://gitlab.com/fcitx/xcb-imdkit.git
cd xcb-imdkit
mkdir build && cd $_ && cmake .. && make -j`nproc` && sudo make install

# Compile fcitx5
git clone https://gitlab.com/fcitx/fcitx5.git
apt install libfmt-dev
cd fcitx5
mkdir build && cd $_ && cmake .. && make -j`nproc` && sudo make install

# libime
git clone https://gitlab.com/fcitx/libime.git
cd libime
git submodule update --init
mkdir build && cd $_ && cmake .. && make -j`nproc` && sudo make install

# fcitx5-qt
git clone https://gitlab.com/fcitx/fcitx5-qt.git
cd fcitx5-qt
mkdir build && cd $_ && cmake .. && make -j`nproc` && sudo make install

find /usr -name "libfcitx5platforminputcontextplugin.so"
set +x

cd ${project_dir}
mkdir build
cd build
qmake -v
qmake CONFIG+=release -spec linux-g++-64 ../VNote.pro
make -j$(nproc)

#
# Pack AppImage using linuxdeployqt
#
mkdir dist
INSTALL_ROOT=${project_dir}/build/dist make install ; tree dist/

# Copy SVG module
mkdir -p ./dist/usr/plugins/iconengines
mkdir -p ./dist/usr/plugins/imageformats
mkdir -p ./dist/usr/plugins/platforminputcontexts
cp /opt/qt59/plugins/iconengines/* ./dist/usr/plugins/iconengines/
cp /opt/qt59/plugins/imageformats/* ./dist/usr/plugins/imageformats/
cp /opt/qt59/plugins/platforminputcontexts/* ./dist/usr/plugins/platforminputcontexts/

# Copy other project files
cp "${project_dir}/README.md" "dist/README.md"
cp "${project_dir}/LICENSE" "dist/LICENSE"
echo ${version} > ./dist/version
echo "${TRAVIS_COMMIT}" >> ./dist/version

# Get linuxdeployqt tool
git clone https://github.com/tamlok/vnote-utils.git vnote-utils.git
cp vnote-utils.git/linuxdeployqt-continuous-x86_64.AppImage ./linuxdeployqt-continuous-x86_64.AppImage
# wget -c "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage"
chmod a+x linuxdeployqt*.AppImage
unset QTDIR; unset QT_PLUGIN_PATH ; unset LD_LIBRARY_PATH
./linuxdeployqt*.AppImage ./dist/usr/share/applications/*.desktop -bundle-non-qt-libs -exclude-libs=libnss3,libnssutil3 -extra-plugins=platformthemes/libqt5ct.so

# Copy translations
cp /opt/qt59/translations/*_zh_CN.qm ./dist/usr/translations/

# Package it for the second time.
./linuxdeployqt*.AppImage ./dist/usr/share/applications/*.desktop -appimage -exclude-libs=libnss3,libnssutil3 -extra-plugins=platformthemes/libqt5ct.so

tree dist/

ls -l *.AppImage

mv VNote-*.AppImage VNote-${version}-x86_64.AppImage

cd ..

exit 0
