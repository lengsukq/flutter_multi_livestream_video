import 'dart:ui';
import 'package:flutter/material.dart';

import '../utils/snackbar.dart';

class IconButtonView extends StatefulWidget {
  final bool showBackgroundColor;
  final IconData icon;
  final Color iconColor;
  final Future Function()? onTap;

  const IconButtonView({
    super.key,
    required this.icon,
    this.showBackgroundColor = true,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  State<IconButtonView> createState() => _IconButtonViewState();
}

class _IconButtonViewState extends State<IconButtonView> {
  bool _loading = false;
  late IconData _icon = widget.icon;

  void onTap() async {
    try {
      if (_loading) {
        return;
      }
      if (widget.onTap != null) {
        setState(() {
          _loading = true;
        });
        var res = await widget.onTap!();
        setState(() {
          _loading = false;
        });
        if (res is IconData) {
          setState(() {
            _icon = res;
          });
        }
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        showSnackBar(context, message: e.toString());
      }
      debugPrint('Error happened: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: _loading
          ? SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.iconColor,
                  ),
                ),
              ),
            )
          : ClipOval(
              child: BackdropFilter(
                filter: widget.showBackgroundColor
                    ? ImageFilter.blur(sigmaX: 12, sigmaY: 12)
                    : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: widget.showBackgroundColor
                            ? Colors.black.withValues(alpha: 0.35)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: widget.showBackgroundColor
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 1,
                              )
                            : null,
                      ),
                      child: Icon(
                        _icon,
                        size: 20,
                        color: widget.iconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
