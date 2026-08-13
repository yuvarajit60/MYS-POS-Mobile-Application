import 'package:flutter/material.dart';
import '../../core/company_provider.dart';

/// Shared branded app bar title: AMSEL logo + the configured company name
/// (fetched from dbo.COMPANY — falls back to "AMSEL Sales" while loading or
/// if the fetch fails, since it works pre-login too).
class AmselAppBarTitle extends StatefulWidget {
  const AmselAppBarTitle({super.key});

  @override
  State<AmselAppBarTitle> createState() => _AmselAppBarTitleState();
}

class _AmselAppBarTitleState extends State<AmselAppBarTitle> {
  @override
  void initState() {
    super.initState();
    CompanyProvider.instance.addListener(_onCompanyChanged);
    CompanyProvider.instance.ensureLoaded();
  }

  void _onCompanyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    CompanyProvider.instance.removeListener(_onCompanyChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = CompanyProvider.instance.company?.companyName ?? 'AMSEL Sales';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset('assets/icon/amsel_icon.png', height: 32),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            name,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.15),
          ),
        ),
      ],
    );
  }
}
