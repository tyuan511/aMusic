import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';

class ImageCover extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const ImageCover({Key? key, required this.url, this.width, this.height, this.fit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExtendedImage(
      image: ExtendedNetworkImageProvider(url, cache: true, headers: {
        'user-agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
      }),
      width: width,
      height: height,
      fit: BoxFit.fill,
    );
  }
}
