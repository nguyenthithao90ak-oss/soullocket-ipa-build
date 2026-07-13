part of '../soul_merge_screen.dart';

class ExplodingPhoto {
  final String url;
  final String text;
  final String type; // 'photo' | 'text'
  final String mood;
  final String dateStr;
  final Offset position;
  final double angle;
  final double targetScale;
  final UniqueKey id = UniqueKey();

  ExplodingPhoto({
    required this.url,
    this.text = '',
    this.type = 'photo',
    this.mood = '💖',
    this.dateStr = '',
    required this.position,
    required this.angle,
    required this.targetScale,
  });
}

class ExplodingPhotoWidget extends StatefulWidget {
  final ExplodingPhoto photo;
  const ExplodingPhotoWidget({super.key, required this.photo});

  @override
  State<ExplodingPhotoWidget> createState() => _ExplodingPhotoWidgetState();
}

class _ExplodingPhotoWidgetState extends State<ExplodingPhotoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Popping entrance and fading exit
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: widget.photo.targetScale)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30, // Popping entrance in first 30% of time
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(widget.photo.targetScale),
        weight: 50, // Holds size
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: widget.photo.targetScale, end: 0.5)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20, // Shrinks out at the end
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.photo.position.dx,
      top: widget.photo.position.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: widget.photo.angle,
                child: child,
              ),
            ),
          );
        },
        child: widget.photo.type == 'text'
            ? Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFF4F93).withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(widget.photo.mood,
                            style: const TextStyle(fontSize: 14)),
                        if (widget.photo.dateStr.isNotEmpty)
                          Text(
                            widget.photo.dateStr,
                            style: SLTheme.quicksand(
                              color: Colors.black54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.photo.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: SLTheme.quicksand(
                        color: Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              )
            : Container(
                width: 140,
                height: 170,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: widget.photo.url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.purple.shade50,
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.purple),
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.purple.shade100,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: Colors.purple,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFFF4F93),
                          size: 12,
                        ),
                        if (widget.photo.dateStr.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.photo.dateStr,
                            style: SLTheme.quicksand(
                              color: Colors.black54,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

