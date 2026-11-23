import QtQuick
import qs.Commons
import "Reader.js" as Reader

// The library: a grid of covers with one cursor shared by keyboard and
// mouse. The book being read comes first.
Item {
  id: view

  property var service: null
  property string filter: ""
  property string viewMode: "grid"
  property int coverSize: 150
  property color fg: Color.foreground
  property color dim: Qt.darker(fg, 1.5)
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  readonly property var shown: Reader.filterBooks(service ? service.books : [], filter)
  readonly property int count: shown.length
  // Keep covers at the chosen size as the panel grows by adding columns.
  readonly property int columns: Math.max(1, Math.floor(width / Style.space(coverSize + 16)))
  property int cursor: 0

  function reset() {
    cursor = 0
    grid.positionViewAtBeginning()
    rows.positionViewAtBeginning()
  }

  function moveTo(index) {
    if (count === 0) return
    cursor = Math.max(0, Math.min(count - 1, index))
    if (viewMode === "list") rows.positionViewAtIndex(cursor, ListView.Contain)
    else grid.positionViewAtIndex(cursor, GridView.Contain)
  }

  function moveCursor(dx, dy) {
    moveTo(viewMode === "list" ? cursor + (dy !== 0 ? dy : dx)
                              : Reader.gridMove(cursor, count, columns, dx, dy))
  }

  function movePage(direction) {
    if (viewMode === "list") {
      moveTo(cursor + direction * Math.max(1, Math.floor(rows.height / rows.rowHeight)))
      return
    }
    var gridRows = Math.max(1, Math.floor(grid.height / grid.cellHeight))
    moveTo(cursor + direction * gridRows * columns)
  }

  // A book Reader does not draw itself was handed to the system's viewer.
  signal handedOff()

  function openAt(index) {
    var book = shown[index]
    if (!book || !service) return
    if (book.external === true) {
      service.openExternal(book.path)
      handedOff()
    } else {
      service.openBook(book.path, book.title)
    }
  }

  function openSelected() {
    openAt(cursor)
  }

  onCountChanged: if (cursor >= count) cursor = Math.max(0, count - 1)

  GridView {
    id: grid

    // Use exactly the library width so this grid and the row-centering
    // calculation below agree on how many columns fit on every monitor.
    readonly property int gutter: Style.space(16)
    readonly property int coverWidth: Math.min(cellWidth - gutter, Style.space(view.coverSize))
    readonly property int coverHeight: Math.round(coverWidth * 1.5)

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    width: parent.width
    visible: view.count > 0 && view.viewMode !== "list"
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    cellWidth: Math.floor(width / view.columns)
    cellHeight: coverHeight + Style.space(58) + Style.space(9)
    model: view.shown

    delegate: Item {
      id: cardCell

      required property var modelData
      required property int index

      // GridView aligns each row to the left, including a partly filled last
      // row. Offset the cards in that row so the row as a whole is centered.
      readonly property int rowStart: Math.floor(index / view.columns) * view.columns
      readonly property int itemsInRow: Math.min(view.columns, view.count - rowStart)
      width: grid.cellWidth
      height: grid.cellHeight

      CoverTile {
        x: Math.round((view.columns - cardCell.itemsInRow) * grid.cellWidth / 2)
        width: grid.cellWidth
        height: grid.cellHeight
        book: cardCell.modelData
        selected: cardCell.index === view.cursor
        progress: view.service ? view.service.progressOf(cardCell.modelData.key) : 0
        coverWidth: grid.coverWidth
        coverHeight: grid.coverHeight
        fg: view.fg
        dim: view.dim
        accent: view.accent
        fontFamily: view.fontFamily
        onEntered: view.cursor = cardCell.index
        onClicked: view.openAt(cardCell.index)
      }
    }
  }

  ListView {
    id: rows

    readonly property int rowHeight: Math.round(Style.space(view.coverSize * 1.5 + 18))
    anchors.fill: parent
    visible: view.count > 0 && view.viewMode === "list"
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height
    model: view.shown
    delegate: Item {
      id: row

      required property var modelData
      required property int index
      width: ListView.view.width
      height: rows.rowHeight

      Rectangle {
        anchors.fill: parent
        anchors.margins: Style.space(3)
        radius: Style.cornerRadius
        color: row.index === view.cursor ? Util.alpha(view.accent, 0.12) : "transparent"
        border.width: row.index === view.cursor ? 1 : 0
        border.color: Util.alpha(view.accent, 0.55)
      }

      Image {
        id: thumbnail
        anchors.left: parent.left
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(Style.space(view.coverSize), parent.height - Style.space(12))
        height: Math.min(width * 1.5, parent.height - Style.space(12))
        source: row.modelData.cover ? Reader.pathToFileUrl(row.modelData.cover) : ""
        sourceSize.width: Number(row.modelData.coverW) > 0 ? row.modelData.coverW : 0
        sourceSize.height: Number(row.modelData.coverH) > 0 ? row.modelData.coverH : 0
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: status === Image.Ready
      }

      Rectangle {
        anchors.fill: thumbnail
        color: "transparent"
        border.width: 1
        border.color: Util.alpha(view.fg, 0.16)
      }

      Column {
        anchors.left: thumbnail.right
        anchors.leftMargin: Style.space(14)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(18)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: row.modelData.title || ""
          color: row.index === view.cursor ? view.accent : view.fg
          font.family: view.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: row.modelData.author || (row.modelData.external ? String(row.modelData.format || "").toUpperCase() : "")
          color: view.dim
          font.family: view.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPositionChanged: view.cursor = row.index
        onClicked: view.openAt(row.index)
      }
    }
  }

  // Nothing to show: say why, and what to do about it.
  Column {
    visible: view.count === 0
    anchors.centerIn: parent
    width: parent.width - Style.space(80)
    spacing: Style.space(10)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      color: view.fg
      font.family: view.fontFamily
      font.pixelSize: Style.font.body
      text: {
        if (!view.service) return ""
        if (view.service.libraryError) return view.service.libraryError
        if (view.filter !== "") return "No books match “" + view.filter + "”"
        if (view.service.scanning || !view.service.scanned) return "Looking for books…"
        return "No books yet"
      }
    }

    Text {
      width: parent.width
      visible: view.service && view.service.scanned && !view.service.scanning
        && view.filter === "" && !view.service.libraryError
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      color: view.dim
      font.family: view.fontFamily
      font.pixelSize: Style.font.bodySmall
      lineHeight: 1.4
      text: view.service && view.service.folder
        ? "Nothing readable was found in " + view.service.folder + "."
        : "Put ebooks in ~/Books or ~/Documents/Books and press r,\nor choose another folder with\nomarchy bar set clumzeez.reader folder ~/your/books"
    }
  }
}
