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
    };
    return words[key]?[zh ? 0 : 1] ?? key;
  }
}
