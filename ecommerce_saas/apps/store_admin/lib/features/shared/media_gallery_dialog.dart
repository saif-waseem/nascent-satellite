import 'package:flutter/material.dart';

class MediaGalleryDialog extends StatelessWidget {
  const MediaGalleryDialog({super.key});

  static const List<Map<String, String>> images = [
    {
      'title': 'Headphones Premium',
      'url': 'https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=500&q=80',
    },
    {
      'title': 'Smart Watch Black',
      'url': 'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=500&q=80',
    },
    {
      'title': 'iPhone Silver',
      'url': 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=500&q=80',
    },
    {
      'title': 'Store Logo Luxury',
      'url': 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=500&q=80',
    },
    {
      'title': 'Fashion Sneaker',
      'url': 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=500&q=80',
    },
    {
      'title': 'Coffee Maker',
      'url': 'https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?w=500&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Image Gallery'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final img = images[index];
            return InkWell(
              onTap: () => Navigator.pop(context, img['url']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(img['url']!, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        color: Colors.black54,
                        child: Text(
                          img['title']!,
                          style: const TextStyle(color: Colors.white, fontSize: 10),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
