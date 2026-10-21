import 'package:flutter/material.dart';

class WhiteboardStrings {
  WhiteboardStrings(this.zh);
  final bool zh;
  static WhiteboardStrings of(BuildContext context) =>
      WhiteboardStrings(Localizations.localeOf(context).languageCode == 'zh');
  String t(String key) {
    const words = {
      'annotate': ['标注 / 移动', 'Draw / navigate'],
      'moveTools': ['拖动工具条', 'Drag toolbar'],
      'pen': ['画笔', 'Pen'],
      'eraser': ['橡皮擦（按笔迹擦除）', 'Eraser (whole stroke)'],
      'highlight': ['高亮', 'Highlight'],
      'circle': ['圆圈', 'Circle'],
      'arrow': ['箭头', 'Arrow'],
      'label': ['文字', 'Text'],
      'undo': ['撤销', 'Undo'],
      'clear': ['清除', 'Clear'],
      'close': ['关闭', 'Close'],
      'navigate': ['操作模式', 'Navigation mode'],
      'cancel': ['取消', 'Cancel'],
      'submit': ['添加', 'Add'],
      'syncError': ['同步失败：', 'Sync failed:'],
      'addPage': ['新增页面', 'Add page'],
      'deletePage': ['删除当前页', 'Delete current page'],
      'page': ['第', 'Page'],
      'whiteboard': ['白板演示', 'Whiteboard'],
      'screenShare': ['屏幕共享', 'Screen Share'],
      'stopSharing': ['停止共享', 'Stop Sharing'],
      'prevPage': ['上一页', 'Previous page'],
      'nextPage': ['下一页', 'Next page'],
      'color': ['颜色', 'Color'],
      'selectColor': ['选择颜色', 'Select Color'],
      'customColor': ['自定义颜色', 'Custom Color'],
      'moreColors': ['更多颜色', 'More colors'],
      'hue': ['色相', 'Hue'],
      'saturation': ['饱和度', 'Saturation'],
      'brightness': ['亮度', 'Brightness'],
      'confirm': ['确定', 'Confirm'],
    };
    return words[key]?[zh ? 0 : 1] ?? key;
  }
}
