// lib/screens/admin/monthly_report/monthly_report_binding.dart

import 'package:get/get.dart';
import '../controllers/monthly_report_controller.dart';

class MonthlyReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MonthlyReportController>(
      () => MonthlyReportController(),
    );
  }
}
