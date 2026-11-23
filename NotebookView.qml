import QtQuick
import qs.Commons

// A plain-text vocabulary notebook. Each line is `term - translation`; it
// stays editable so translations can be pasted beside their terms.
Item {
  id: root

  property var service: null
  property color fg: Color.foreground
  property color dim: Qt.darker(fg, 1.5)
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  readonly property bool editing: editor.activeFocus

  signal backRequested()

  function focusEditor() { editor.forceActiveFocus() }

  function scrollBy(pixels) {
    if (pixels === 0) return
    var end = Math.max(0, scroller.contentHeight - scroller.height)
    if (end <= 0) return
    var from = glide.running ? glide.to : scroller.contentY
    var target = Math.max(0, Math.min(end, from + pixels))
    glide.stop()
    glide.from = scroller.contentY
    glide.to = target
    glide.start()
  }

  function page(direction) {
    var lineStep = Math.max(1, editor.font.pixelSize * 1.6)
    scrollBy(direction * Math.max(lineStep * 2, scroller.height - lineStep * 2))
  }

  function move(dx, dy) {
    var lineStep = Math.max(1, editor.font.pixelSize * 1.6)
    if (dx !== 0) page(dx)
    if (dy !== 0) {
      if (root.service && root.service.paged) page(dy)
      else scrollBy(dy * lineStep * 3)
    }
  }

  NumberAnimation {
    id: glide
    target: scroller
    property: "contentY"
    duration: 140
    easing.type: Easing.OutCubic
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: Util.alpha(root.fg, 0.035)
    border.width: 1
    border.color: Util.alpha(root.fg, 0.12)
  }

  Text {
    id: hint
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.top: parent.top
    anchors.topMargin: Style.space(12)
    anchors.right: copyButton.left
    anchors.rightMargin: Style.space(10)
    textFormat: Text.PlainText
    text: "Press M on selected book text to add it. Add translations after “ - ”. Select a matching word in the book to see its translation above."
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.Wrap
  }

  Rectangle {
    id: copyButton
    anchors.top: parent.top
    anchors.topMargin: Style.space(8)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    width: copyLabel.implicitWidth + Style.space(22)
    height: Style.space(30)
    radius: Style.cornerRadius
    color: copyMouse.containsMouse ? Util.alpha(root.accent, 0.2) : Util.alpha(root.fg, 0.07)

    Text {
      id: copyLabel
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "Copy words"
      color: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      id: copyMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.service) root.service.copyNotebookWords()
    }
  }

  Flickable {
    id: scroller
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(12)
    anchors.top: hint.bottom
    anchors.topMargin: Style.space(10)
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(12)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    contentWidth: editor.width
    contentHeight: editor.height
    interactive: contentHeight > height

    TextEdit {
      id: editor
      x: Style.space(4)
      width: Math.max(0, scroller.width - Style.space(8))
      height: Math.max(scroller.height, contentHeight + Style.space(16))
      textFormat: TextEdit.PlainText
      text: root.service ? root.service.notebook : ""
      color: root.fg
      selectionColor: Util.alpha(root.accent, 0.32)
      selectedTextColor: root.fg
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: TextEdit.Wrap
      selectByMouse: true
      selectByKeyboard: true
      activeFocusOnPress: true
      persistentSelection: true
      onTextChanged: if (root.service && text !== root.service.notebook) root.service.setNotebook(text)
      Keys.onPressed: function(event) {
        if (event.modifiers !== Qt.NoModifier) return
        var dx = event.key === Qt.Key_Left ? -1 : (event.key === Qt.Key_Right ? 1 : 0)
        var dy = event.key === Qt.Key_Up ? -1 : (event.key === Qt.Key_Down ? 1 : 0)
        if (dx === 0 && dy === 0) return
        root.move(dx, dy)
        event.accepted = true
      }
      Keys.onEscapePressed: function(event) {
        event.accepted = true
        root.backRequested()
      }
    }
  }
}
