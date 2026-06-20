class TickerItem {
  final int id;
  final String text;
  final String? bgColor;
  final String? textColor;

  TickerItem({
    required this.id,
    required this.text,
    this.bgColor,
    this.textColor,
  });

  factory TickerItem.fromJson(Map<String, dynamic> json) {
    return TickerItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      text: json['ticker_text']?.toString() ??
          json['tickerText']?.toString() ??
          json['ticker']?.toString() ??
          json['ticker_type']?.toString() ??
          json['tickerType']?.toString() ??
          json['text']?.toString() ??
          json['content']?.toString() ??
          json['header_text']?.toString() ??
          json['headerText']?.toString() ??
          json['title']?.toString() ??
          json['description']?.toString() ??
          '',
      bgColor: json['bg_color']?.toString() ?? json['bgColor']?.toString(),
      textColor: json['text_color']?.toString() ?? json['textColor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'bg_color': bgColor,
      'text_color': textColor,
    };
  }
}
