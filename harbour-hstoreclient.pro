TARGET = harbour-hstoreclient

CONFIG += sailfishapp

VERSION = 0.2.0

QT += network

SOURCES += src/harbour-hstoreclient.cpp

OTHER_FILES += qml/harbour-hstoreclient.qml \
               qml/pages/FirstPage.qml \
               qml/pages/DetailPage.qml \
               rpm/harbour-hstoreclient.spec \
               rpm/harbour-hstoreclient.desktop

RESOURCES +=

# translations support (empty file)
