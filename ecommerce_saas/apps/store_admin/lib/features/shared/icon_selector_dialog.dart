import 'package:flutter/material.dart';

class IconSelectorDialog extends StatelessWidget {
  const IconSelectorDialog({super.key});

  static final List<int> availableIcons = [
    58900, // headphones
    58941, // watch
    0xe8b8, // settings
    0xe871, // dashboard
    0xe7e9, // shopping_bag
    0xe54d, // restaurant
    0xe3af, // local_shipping
    0xef64, // loyalty
    0xe7ef, // group
    0xe0b0, // chat
    0xe190, // store
    0xe227, // attach_money
    0xe3e7, // smartphone
    0xe31e, // laptop
    0xe332, // mouse
    0xe32c, // keyboard
    0xe32a, // developer_board
    0xe325, // computer
    0xe406, // music_note
    0xe405, // movie
    0xe52f, // directions_car
    0xe532, // directions_bike
    0xe544, // local_florist
    0xe54c, // local_pizza
    0xe566, // navigation
    0xe57a, // place
    0xe80d, // flight
    0xe838, // star
    0xe84f, // account_circle
    0xe853, // account_box
    0xe87c, // face
    0xe88a, // home
    0xe897, // lock
    0xe8f4, // visibility
    0xea40, // spa
    0xeb3b, // beach_access
    0xeb41, // cafe
    0xeb43, // fitness_center
    0xeb44, // kitchen
    0xeb48, // pool
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Icon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10),
          itemCount: availableIcons.length,
          itemBuilder: (context, index) {
            final iconCode = availableIcons[index];
            return InkWell(
              onTap: () => Navigator.pop(context, iconCode.toString()),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons')),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
