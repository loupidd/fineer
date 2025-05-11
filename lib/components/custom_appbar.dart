// lib/widgets/custom_appbar.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fineer/cons.dart';

class CustomAppBar extends PreferredSize {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final bool centerTitle;

  CustomAppBar({
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.centerTitle = true,
    super.key,
  }) : super(
          preferredSize: const Size.fromHeight(56.0),
          child: AppBar(
            title: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            backgroundColor: Colors.white,
            foregroundColor: ColorConstants.textPrimaryColor,
            centerTitle: centerTitle,
            elevation: 1,
            leading: showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => Get.back(),
                  )
                : null,
            actions: actions,
          ),
        );
}
