import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../core/presentation/widgets/page_header.dart';
import '../bloc/fd_counters_cubit.dart';
import '../widgets/dashboard_content.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final FdCountersCubit _fdCubit;

  @override
  void initState() {
    super.initState();
    _fdCubit = sl<FdCountersCubit>();
    _fdCubit.load();
  }

  @override
  void dispose() {
    _fdCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocProvider.value(
      value: _fdCubit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: l10n.menuStatistics),
          Expanded(child: DashboardContent(l10n: l10n)),
        ],
      ),
    );
  }
}
