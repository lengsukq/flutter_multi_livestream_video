import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/views/icon.button.view.dart';

import '../models/meeting.model.dart';

class TitleView extends StatelessWidget {
  final String title;
  final void Function(bool didStop)? onLeave;

  const TitleView({super.key, this.title = '', this.onLeave});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 14,
      left: 14,
      right: 14,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButtonView(
                  icon: Icons.arrow_back_ios_new_rounded,
                  showBackgroundColor: false,
                  onTap: () async {
                    var res = await MeetingModel().stopMeeting();
                    if (onLeave != null) {
                      onLeave!(res);
                    }
                  },
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          title.isEmpty ? 'Live Meeting' : title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButtonView(
                  icon: MeetingModel().controlLock
                      ? Icons.lock_rounded
                      : Icons.lock_open_rounded,
                  showBackgroundColor: false,
                  onTap: () async {
                    MeetingModel().controlLock = !MeetingModel().controlLock;
                    MeetingModel().controlVisible.add(MeetingModel().controlLock);
                    return MeetingModel().controlLock
                        ? Icons.lock_rounded
                        : Icons.lock_open_rounded;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
