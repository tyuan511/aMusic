import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ImageCover extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const ImageCover({Key? key, required this.url, this.width, this.height, this.fit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return url == null
        ? Image.asset(
            'assets/images/placeholder.jpg',
            width: width,
            height: height,
            fit: BoxFit.fill,
          )
        : CachedNetworkImage(
            imageUrl: url!,
            width: width,
            height: height,
            fit: BoxFit.fill,
            httpHeaders: const {
              'User-Agent':
                  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36'
            },
          );
  }
}
