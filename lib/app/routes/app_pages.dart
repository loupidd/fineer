import 'package:get/get.dart';

import '../../main.dart';
import '../modules/add_pegawai/bindings/add_pegawai_binding.dart';
import '../modules/add_pegawai/views/add_pegawai_view.dart';
import '../modules/all_presensi/bindings/all_presensi_binding.dart';
import '../modules/all_presensi/views/all_presensi_view.dart';
import '../modules/detail_presensi/bindings/detail_presensi_binding.dart';
import '../modules/detail_presensi/views/detail_presensi_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/monthly_report/bindings/monthly_report_binding.dart';
import '../modules/monthly_report/views/monthly_report_view.dart';
import '../modules/overtime/bindings/overtime_binding.dart';
import '../modules/overtime/views/overtime_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/profile_view.dart';

// ignore_for_file: prefer_const_constructors

// ignore_for_file: constant_identifier_names

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.HOME;

  static final routes = [
    GetPage(
        name: _Paths.HOME,
        page: () => HomeView(),
        binding: HomeBinding(),
        transition: Transition.fadeIn),
    GetPage(
      name: _Paths.ADD_PEGAWAI,
      page: () => const AddPegawaiView(),
      binding: AddPegawaiBinding(),
    ),
    GetPage(
        name: _Paths.LOGIN,
        page: () => LoginView(),
        binding: LoginBinding(),
        transition: Transition.fadeIn),
    GetPage(
        name: _Paths.DETAIL_PRESENSI,
        page: () => DetailPresensiView(),
        binding: DetailPresensiBinding(),
        transition: Transition.rightToLeft),
    GetPage(
        name: _Paths.ALL_PRESENSI,
        page: () => AllPresensiView(),
        binding: AllPresensiBinding(),
        transition: Transition.fadeIn),
    GetPage(
        name: _Paths.OVERTIME,
        page: () => OvertimeView(),
        binding: OvertimeBinding(),
        transition: Transition.fadeIn),
    GetPage(
      name: _Paths.SPLASH,
      page: () => const SplashScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: _Paths.PROFILE,
      page: () => ProfileView(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: _Paths.MONTHLY_REPORT,
      page: () => const MonthlyReportView(),
      binding: MonthlyReportBinding(),
    ),
  ];
}
