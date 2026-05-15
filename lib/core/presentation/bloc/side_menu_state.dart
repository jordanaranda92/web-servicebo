import 'package:equatable/equatable.dart';

class SideMenuState extends Equatable {
  final bool isExpanded;

  const SideMenuState({this.isExpanded = true});

  @override
  List<Object?> get props => [isExpanded];
}
