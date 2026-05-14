import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/localization/l10n/app_localizations.dart';
import '../../../../app/router/router.dart';
import '../../../../app/theme/theme_constants.dart';
import '../bloc/login_cubit.dart';
import '../bloc/login_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocProvider(
      create: (_) => sl<LoginCubit>(),
      child: Scaffold(
        body: BlocConsumer<LoginCubit, LoginState>(
          listener: (context, state) {
            if (state is LoginSuccess) {
              context.go(AppRoutes.home);
            }
            if (state is LoginError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_resolveErrorMessage(l10n, state.message)),
                  backgroundColor: colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is LoginLoading;

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary,
                    colorScheme.primaryContainer,
                    colorScheme.surface,
                  ],
                ),
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: Card(
                    elevation: AppElevation.high,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.large),
                    ),
                    child: Container(
                      width: 420,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.xxl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppRadii.medium,
                            ),
                            child: Image.asset(
                              'assets/images/logo-servicebo.png',
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Title
                          Text(
                            l10n.loginTitle,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.loginSubtitle,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Email field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.loginEmailLabel,
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextField(
                                controller: _emailController,
                                enabled: !isLoading,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  hintText: l10n.loginEmailHint,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // Password field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.loginPasswordLabel,
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              TextField(
                                controller: _passwordController,
                                enabled: !isLoading,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submit(context),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),

                          // Remember me checkbox
                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: isLoading
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                              ),
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _rememberMe = !_rememberMe;
                                        });
                                      },
                                child: Text(
                                  l10n.loginRememberMe,
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Sign in button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: isLoading
                                  ? null
                                  : () => _submit(context),
                              child: isLoading
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : Text(l10n.loginSignInButton),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    context.read<LoginCubit>().login(
      email: _emailController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  String _resolveErrorMessage(AppLocalizations l10n, String key) {
    return switch (key) {
      'loginErrorEmailEmpty' => l10n.loginErrorEmailEmpty,
      'loginErrorEmailInvalid' => l10n.loginErrorEmailInvalid,
      'loginErrorPasswordEmpty' => l10n.loginErrorPasswordEmpty,
      'loginErrorInvalidCredentials' => l10n.loginErrorInvalidCredentials,
      'loginErrorUserDisabled' => l10n.loginErrorUserDisabled,
      'loginErrorTooManyRequests' => l10n.loginErrorTooManyRequests,
      'loginErrorNetwork' => l10n.loginErrorNetwork,
      _ => l10n.loginErrorUnknown,
    };
  }
}
