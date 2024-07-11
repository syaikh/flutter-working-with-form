import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:myapp/data/categories.dart';
import 'package:myapp/models/grocery_item.dart';
import 'package:myapp/widgets/new_item.dart';

class GroceryList extends StatefulWidget {
  const GroceryList({super.key});

  @override
  State<GroceryList> createState() => _GroceryListState();
}

class _GroceryListState extends State<GroceryList> {
  var _isLoading = true;
  List<GroceryItem> _groceryItems = [];
  String? _error;
  // String? _undoError;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() async {
    // test error scenario
    // final url = Uri.https(
    //     'aflutter-prep-3b1b4-default-rtdb.asia-southeast1.firebasedatabase.app',
    //     'shopping-list.json');

    final url = Uri.https(
        'flutter-prep-3b1b4-default-rtdb.asia-southeast1.firebasedatabase.app',
        'shopping-list.json');

    try {
      final response = await http.get(url);
      if (response.statusCode >= 400) {
        setState(() {
          _error = 'Failed to fetch data. Please try again later.';
        });
        return;
      }
      // this check depends on backend.
      // Firebase return string 'null',
      // others might be based on statuscode check
      if (response.body == 'null') {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final Map<String, dynamic> listData = json.decode(response.body);
      final List<GroceryItem> loadedItems = [];
      for (final item in listData.entries) {
        final category = categories.entries
            .firstWhere(
              (catItem) => catItem.value.title == item.value['category'],
            )
            .value;
        loadedItems.add(
          GroceryItem(
            id: item.key,
            name: item.value['name'],
            quantity: item.value['quantity'],
            category: category,
          ),
        );
      }
      setState(() {
        _groceryItems = loadedItems;
        _isLoading = false;
      });
    } catch (e) {
      // } on Exception catch (e) {
      _error = 'Something went wrong. Please try again later.';
      print(e);
    }
  }

  void _addItem() async {
    final newItem = await Navigator.of(context).push(
      // await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const NewItem(),
      ),
    );
    // _loadItems();

    if (newItem == null) {
      return;
    }
    setState(() {
      _groceryItems.add(newItem);
    });
  }

  GroceryItem? _removeItemOnScreen(int index) {
    GroceryItem? removedItem;
    setState(() {
      removedItem = _groceryItems.removeAt(index);
    });
    return removedItem;
  }

  Future<int> _removeItemOnBackend(GroceryItem item) async {
    final url = Uri.https(
        'flutter-prep-3b1b4-default-rtdb.asia-southeast1.firebasedatabase.app',
        'shopping-list/${item.id}.json');
    final response = await http.delete(
      url,
    );
    return response.statusCode;
  }

  void _undoRemoveItemOnScreen(GroceryItem item, int index) {
    setState(() {
      _groceryItems.insert(index, item);
    });
  }

  Future<int> _resaveItem(GroceryItem removedItem) async {
    final url = Uri.https(
        'flutter-prep-3b1b4-default-rtdb.asia-southeast1.firebasedatabase.app',
        'shopping-list.json');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode(
        {
          'name': removedItem.name,
          'quantity': removedItem.quantity,
          'category': removedItem.category.title,
        },
      ),
    );
    return response.statusCode;
  }

  void _showErrorSnackBar(BuildContext ctx, String errorMessage) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content = const Center(
      child: Text(
        'No grocery item available. \nPlease add one.',
        textAlign: TextAlign.center,
      ),
    );
    if (_isLoading) {
      content = const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (_groceryItems.isNotEmpty) {
      content = ListView.builder(
        itemCount: _groceryItems.length,
        itemBuilder: (ctx, index) => Dismissible(
          key: ValueKey(_groceryItems[index].id),
          direction: DismissDirection.startToEnd,
          onDismissed: (direction) async {
            final messenger = ScaffoldMessenger.of(ctx);
            GroceryItem? removedItem = _removeItemOnScreen(index);
            final int responseStatusCode =
                await _removeItemOnBackend(removedItem!);
            if (responseStatusCode >= 400) {
              _undoRemoveItemOnScreen(removedItem, index);
              if (!ctx.mounted) return;
              _showErrorSnackBar(
                ctx,
                'Delete item failed. Please try again later',
              );
              return;
            }
            // if (!ctx.mounted) return;
            messenger.showSnackBar(
              SnackBar(
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () async {
                    final int responseStatusCode =
                        await _resaveItem(removedItem);
                    if (responseStatusCode >= 400) {
                      // failed post/save undoed item
                      if (!ctx.mounted) return;
                      _showErrorSnackBar(
                        ctx,
                        'Undo failed. Please try again later',
                      );
                    } else {
                      _undoRemoveItemOnScreen(removedItem, index);
                    }
                  },
                ),
                content: const Text('Item removed'),
              ),
            );
          },
          child: ListTile(
            title: Text(_groceryItems[index].name),
            leading: Container(
              width: 24,
              height: 24,
              color: _groceryItems[index].category.color,
            ),
            trailing: Text(
              _groceryItems[index].quantity.toString(),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      content = Center(
        child: Text(_error!),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Groceries'),
        actions: [
          IconButton(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: content,
    );
  }
}
