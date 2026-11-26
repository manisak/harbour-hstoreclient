TARGET = harbour-hstoreclient

# Pure-QML Sailfish OS app — launched via `sailfish-qml harbour-hstoreclient`.
# No C++ launcher required. The .desktop Exec points at sailfish-qml.

# sailfishapp CONFIG is only used for install paths / icon handling.
CONFIG += sailfishapp
CONFIG -= sailfishapp_i18n  # no translations bundled yet

VERSION = 0.4.1

# No SOURCES — pure QML.
SOURCES +=

OTHER_FILES += qml/harbour-hstoreclient.qml \
               rpm/harbour-hstoreclient.spec \
               rpm/harbour-hstoreclient.desktop

# Deploy QML + desktop + icon via qmake install rules (sailfishapp provides them).
