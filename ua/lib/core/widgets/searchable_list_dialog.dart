import 'package:flutter/material.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';

class SearchableListDialog extends StatefulWidget {
  final String title;
  final List<dynamic> items; // Can be List<String> or List<Map<String, String>>
  final List<String>? subtextItems;
  final String lang;

  const SearchableListDialog({
    super.key,
    required this.title,
    required this.items,
    this.subtextItems,
    required this.lang,
  });

  @override
  State<SearchableListDialog> createState() => _SearchableListDialogState();
}

class _SearchableListDialogState extends State<SearchableListDialog> {
  late List<dynamic> filteredItems;
  late List<String>? filteredSubtext;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
    filteredSubtext = widget.subtextItems;
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredItems = widget.items;
        filteredSubtext = widget.subtextItems;
      } else {
        final results = <int>[];
        for (int i = 0; i < widget.items.length; i++) {
          final item = widget.items[i];
          final text = item is Map ? (item[widget.lang] ?? item['en']).toString() : item.toString();
          if (text.toLowerCase().contains(query.toLowerCase()) || 
              (widget.subtextItems != null && widget.subtextItems![i].toLowerCase().contains(query.toLowerCase()))) {
            results.add(i);
          }
        }
        filteredItems = results.map((i) => widget.items[i]).toList();
        filteredSubtext = widget.subtextItems != null ? results.map((i) => widget.subtextItems![i]).toList() : null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.lang == 'ar' ? 'بحث...' : 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: _filter,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  final text = item is Map ? (item[widget.lang] ?? item['en']).toString() : item.toString();
                  final returnVal = item is Map ? item['en'].toString() : item.toString();
                  
                  return ListTile(
                    title: Text(text),
                    subtitle: filteredSubtext != null ? Text(filteredSubtext![index], style: const TextStyle(fontSize: 12)) : null,
                    onTap: () => Navigator.pop(context, returnVal), // Always return English/Base value for DB consistency
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.get('cancel', widget.lang)),
        ),
      ],
    );
  }
}
