import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GalleryPage(),
    );
  }
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  // Sample gallery data
  final List<GalleryItem> galleryItems = [
    GalleryItem(
      id: 1,
      imageUrl: "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee",
      prompt: "A futuristic cyberpunk city street at night, neon signs, rain slick pavement...",
      tags: const ["CINEMATIC", "Cyberpunk", "8k"],
      updatedAt: "Today",
    ),
    GalleryItem(
      id: 2,
      imageUrl: "https://images.unsplash.com/photo-1461749280684-ddefd3519c41",
      prompt: "Abstract digital art with vibrant colors and geometric shapes...",
      tags: const ["ABSTRACT", "Digital", "Colorful"],
      updatedAt: "Yesterday",
    ),
    GalleryItem(
      id: 3,
      imageUrl: "https://images.unsplash.com/photo-1517694712202-14dd9538aa97",
      prompt: "Professional portrait photography with studio lighting and bokeh background...",
      tags: const ["PORTRAIT", "Studio", "Professional"],
      updatedAt: "2 days ago",
    ),
    GalleryItem(
      id: 4,
      imageUrl: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745",
      prompt: "Landscape photography of mountains with golden hour lighting...",
      tags: const ["LANDSCAPE", "Nature", "Golden Hour"],
      updatedAt: "3 days ago",
    ),
    GalleryItem(
      id: 5,
      imageUrl: "https://images.unsplash.com/photo-1501746074465-4cebaf45b800",
      prompt: "Ocean waves crashing on beach with dramatic sky and lighting...",
      tags: const ["OCEAN", "Waves", "Beach"],
      updatedAt: "4 days ago",
    ),
    GalleryItem(
      id: 6,
      imageUrl: "https://images.unsplash.com/photo-1504384308090-c894fdcc538d",
      prompt: "Modern architecture with clean lines and minimalist design...",
      tags: const ["ARCHITECTURE", "Modern", "Minimal"],
      updatedAt: "5 days ago",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Prompt Gallery",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(
                "https://i.pravatar.cc/150",
              ),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: galleryItems.length,
        itemBuilder: (context, index) {
          return GalleryCard(
            item: galleryItems[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PromptDetailsPage(item: galleryItems[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Gallery Card Widget
class GalleryCard extends StatelessWidget {
  final GalleryItem item;
  final VoidCallback onTap;

  const GalleryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white10,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  SizedBox(
                    height: 24,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (int i = 0; i < (item.tags.length > 2 ? 2 : item.tags.length); i++)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: TagChip(text: item.tags[i]),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Prompt preview
                  Text(
                    item.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Updated time
                  Text(
                    "Updated ${item.updatedAt}",
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Detailed Prompt Page
class PromptDetailsPage extends StatelessWidget {
  final GalleryItem item;

  const PromptDetailsPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Prompt Details",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // IMAGE
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  item.imageUrl,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // TAGS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  for (int i = 0; i < item.tags.length; i++)
                    Padding(
                      padding: EdgeInsets.only(right: i < item.tags.length - 1 ? 8 : 0),
                      child: TagChip(text: item.tags[i]),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // PROMPT BOX
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "PROMPT TEXT",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Updated ${item.updatedAt}",
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.prompt,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // BUTTON
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.rocket_launch),
                  label: const Text(
                    "Use in In-App Generator",
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// TAG CHIP
class TagChip extends StatelessWidget {
  final String text;

  const TagChip({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFFB794F4),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// GALLERY ITEM MODEL
class GalleryItem {
  final int id;
  final String imageUrl;
  final String prompt;
  final List<String> tags;
  final String updatedAt;

  GalleryItem({
    required this.id,
    required this.imageUrl,
    required this.prompt,
    required this.tags,
    required this.updatedAt,
  });
}
