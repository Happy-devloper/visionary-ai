import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'main.dart';

// ---------------- TAB CHIP ----------------
class TabChip extends StatelessWidget {
  final String title;
  final bool isSelected;

  const TabChip({
    super.key,
    required this.title,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        backgroundColor:
            isSelected ? Colors.white : const Color(0xFF1E1E1E),
        label: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ---------------- GALLERY DISCOVERY CARD ----------------
class GalleryDiscoveryCard extends StatelessWidget {
  final AiImage aiImage;
  final VoidCallback onTap;

  const GalleryDiscoveryCard({
    super.key,
    required this.aiImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final promptWords = aiImage.prompt.split(' ');
    final shortTitle = promptWords.length > 3
        ? '${promptWords.take(3).join(' ')}...'
        : aiImage.prompt;

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: aiImage.imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: aiImage.imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Flux Model',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
