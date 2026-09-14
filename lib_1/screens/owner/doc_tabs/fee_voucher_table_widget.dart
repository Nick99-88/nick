import 'package:flutter/material.dart';

class FeeVoucherTableWidget extends StatelessWidget {
  final List<dynamic> content;
  final String studentName;
  final String fatherName;

  const FeeVoucherTableWidget({
    super.key,
    required this.content,
    required this.studentName,
    required this.fatherName,
  });

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text(
          "No fee voucher ledgers found.",
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 3D Header Bar of Table
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFF2E7D32), // Green 3D Header
                child: const Row(
                  children: [
                    Icon(Icons.payments_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      "FINANCIAL VOUCHER DIRECTORY",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.1),
                    ),
                  ],
                ),
              ),

              // Interactive Scalable/Scrollable Canvas Area
              Container(
                height: 350,
                padding: const EdgeInsets.all(12),
                child: InteractiveViewer(
                  // 🏛| Logic: InteractiveViewer with constrained: false allows unlimited 2D pan & zoom!
                  constrained: false,
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(150.0),
                    border: TableBorder.all(color: Colors.grey.shade200, width: 1.5, borderRadius: BorderRadius.circular(8)),
                    children: [
                      // Header Row
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: const [
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('STUDENT & FATHER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('FEE CATEGORY/ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('LEDGER KEY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('AMOUNT (PKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
                            ),
                          ),
                        ],
                      ),

                      // Content Rows (Iterating through individual fee items)
                      ...content.map((entry) {
                        if (entry is! Map) return TableRow(children: const [TableCell(child: SizedBox())]);
                        
                        final String feeType = entry['fee_type'] ?? entry['label'] ?? 'Custom Fee Item';
                        final String key = entry['key'] ?? 'fee_item';
                        final String amount = (entry['amount'] ?? 0).toString();

                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text("$studentName\n($fatherName)", style: const TextStyle(fontSize: 12, color: Color(0xFF263238), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(feeType, style: const TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(key, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  "PKR $amount", 
                                  style: const TextStyle(
                                    fontSize: 12, 
                                    color: Colors.green, 
                                    fontWeight: FontWeight.bold
                                  )
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
