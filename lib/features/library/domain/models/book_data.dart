class BookData {
  final String? title;
  final String? author;
  final String? description;
  final String? thumbnail;
  final String link;
  final String? info;
  final Map<String, dynamic>? metadata;

  const BookData({
    this.title,
    this.author,
    this.description,
    this.thumbnail,
    required this.link,
    this.info,
    this.metadata,
  });

  factory BookData.fromJson(Map<String, dynamic> json) {
    return BookData(
      title: json['title'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
      thumbnail: json['thumbnail'] as String?,
      link: json['link'] as String,
      info: json['info'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'author': author,
      'description': description,
      'thumbnail': thumbnail,
      'link': link,
      'info': info,
      'metadata': metadata,
    };
  }
}
