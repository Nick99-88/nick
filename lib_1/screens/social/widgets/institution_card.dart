import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';

class InstitutionCard extends StatelessWidget {
  final String name;
  final String ref;
  final String type;
  final String id;
  final String? ownerName;
  final String? description;
  final String? address;
  final String? email;
  final bool? isSetupComplete;
  final bool? hasPfp;
  final VoidCallback onTap;

  const InstitutionCard({
    super.key,
    required this.name,
    required this.ref,
    required this.type,
    required this.id,
    this.ownerName,
    this.description,
    this.address,
    this.email,
    this.isSetupComplete,
    this.hasPfp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pfpUrl = "${StarlightConstants.apiBaseUrl}/explore/pfp/institution/$id";

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                image: DecorationImage(
                  image: NetworkImage(pfpUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {},
                ),
              ),
              child: const Icon(Icons.account_balance_rounded, color: Colors.orange, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              type.toUpperCase(),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 9, fontWeight: FontWeight.w600),
            ),
            if (ownerName != null && ownerName!.isNotEmpty)
              Text(
                "Owner: $ownerName",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "REF: $ref",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 8, fontFamily: 'monospace'),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: ref));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('REF $ref copied'), duration: const Duration(seconds: 1)),
                    );
                  },
                  child: Icon(Icons.copy_rounded, size: 9, color: Colors.grey.shade400),
                ),
              ],
            ),
            if (address != null && address!.isNotEmpty)
              Text(
                address!,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 7, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (email != null && email!.isNotEmpty)
              Text(
                email!,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 7),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (description != null && description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  description!,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 7),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: StarlightTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text("VIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Share.share('Check out $name on Starlight Institution\nhttps://institution.site/i/$id');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.share_rounded, color: Colors.orange, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
