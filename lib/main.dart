// ignore_for_file: no_logic_in_create_state

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

var mainColorBright = const Color(0xFF8CA095);
var mainColorDark = const Color(0xFF2F5942);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const RecipeApp());
}

class Recipe {
  final String id;
  final String title;
  final String imageUrl;
  final String keywords;
  final int duration;
  final List<dynamic> description;
  final List<dynamic> ingredients;

  Recipe(this.id, this.title, this.imageUrl, this.keywords, this.duration,
      this.description, this.ingredients);
}

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: RecipeList());
  }
}

class RecipeList extends StatefulWidget {
  const RecipeList({Key? key}) : super(key: key);

  @override
  _RecipeListState createState() => _RecipeListState();
}

class _RecipeListState extends State<RecipeList> {
  String _searchQuery = '';

  void _updateSearchQuery(String newQuery) {
    setState(() {
      _searchQuery = newQuery;
    });
  }

  void _dismissKeyboard(BuildContext context) {
    // Use FocusScope to move the focus away from the TextFormField and dismiss the keyboard
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          primaryColor: mainColorBright,
        ),
        home: GestureDetector(
          onTap: () {
            _dismissKeyboard(context);
          },
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight + 3),
              child: CustomAppBar(onSearchQueryChanged: _updateSearchQuery),
            ),
            body: RecipeListView(searchQuery: _searchQuery),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const AddRecipeScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0, -1);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));

                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                  ),
                );
              },
              backgroundColor: mainColorBright,
              child: const Center(child: Icon(Icons.add)),
            ),
          ),
        ));
  }
}

class UnitDropdownMenu extends StatefulWidget {
  final Function(String, int)
      onItemSelected; // Define the callback function as a parameter
  final int index;
  final ValueNotifier<String> selectedItem;

  const UnitDropdownMenu(
      {super.key,
      required this.onItemSelected,
      required this.selectedItem,
      required this.index});

  @override
  _UnitDropdownMenuState createState() => _UnitDropdownMenuState();
}

class _UnitDropdownMenuState extends State<UnitDropdownMenu> {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      underline: Container(),
      icon: const Center(
        child: Icon(
          // Customize the icon for the small arrow
          Icons.arrow_drop_down, // Replace with your desired icon
          color: Color(0xFF8CA095), // Replace with your desired color
        ),
      ),
      value: widget.selectedItem.value,
      onChanged: (newValue) {
        Future.delayed(Duration.zero, () {
          setState(() {
            widget.selectedItem.value = newValue!; // Update ValueNotifier value
            widget.onItemSelected(newValue, widget.index);
          });
        });
      },
      items: <String>[
        '',
        'g',
        'kg',
        'ml',
        'l',
        'EL',
        'TL',
        'Stk',
      ].map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
    );
  }
}

class AddRecipeScreen extends StatefulWidget {
  final Recipe? recipe;

  const AddRecipeScreen({this.recipe, Key? key}) : super(key: key);
  const AddRecipeScreen.withValues(Recipe this.recipe, {Key? key})
      : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _AddRecipeScreenState createState() {
    if (recipe != null) {
      return _AddRecipeScreenState.withValues(recipe!);
    } else {
      return _AddRecipeScreenState.init();
    }
  }
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  File? _image; // Store the selected image file
  TextEditingController _titleController = TextEditingController();
  TextEditingController _durationController = TextEditingController();
  List<TextEditingController> _keywordControllers = [];
  List<TextEditingController> _ingredientControllers = [
    TextEditingController()
  ];
  List<TextEditingController> _amountControllers = [TextEditingController()];
  List<TextEditingController> _descriptionControllers = [];
  List<String> _savedKeywords = []; // List to store the saved keywords
  List<ValueNotifier<String>> _selectedUnits = [ValueNotifier('')];
  // List<String> _units = [];
  String _imageUrl = '';
  List<Container> _keywordContainers = [];
  String? _recipeId;
  bool _savingRecipe = false;
  String _pageTitle = 'Neues Rezept hinzufügen';

  _AddRecipeScreenState.init();

  factory _AddRecipeScreenState.withValues(Recipe recipe) {
    final state = _AddRecipeScreenState.init();

    TextEditingController titleController = TextEditingController();
    titleController.text = recipe.title;

    TextEditingController durationController = TextEditingController();
    durationController.text = recipe.duration.toString();

    List<TextEditingController> keywordControllers = [];
    List<String> keywords = recipe.keywords.split(', ');

    List<TextEditingController> ingredientControllers = [];
    List<TextEditingController> amountControllers = [];
    List<String> units = [];
    List<ValueNotifier<String>> selectedUnits = [];

    for (var ingredient in recipe.ingredients) {
      TextEditingController typeController = TextEditingController();
      TextEditingController amountController = TextEditingController();

      typeController.text = ingredient['type'];
      if (ingredient['amount'] != null) {
        amountController.text = ingredient['amount'].toString();
      }
      if (ingredient['unit'] != null) {
        selectedUnits.add(ValueNotifier(ingredient['unit']));
        units.add(ingredient['unit']);
      } else {
        selectedUnits.add(ValueNotifier(''));
        units.add('');
      }

      ingredientControllers.add(typeController);
      amountControllers.add(amountController);
    }

    List<TextEditingController> descriptionControllers = [];
    for (String description in recipe.description) {
      TextEditingController descriptionController = TextEditingController();
      descriptionController.text = description;
      descriptionControllers.add(descriptionController);
    }

    state._imageUrl = recipe.imageUrl;
    state._titleController = titleController;
    state._durationController = durationController;
    state._keywordControllers = keywordControllers;
    state._ingredientControllers = ingredientControllers;
    state._amountControllers = amountControllers;
    state._descriptionControllers = descriptionControllers;
    state._recipeId = recipe.id;
    state._savedKeywords = keywords;
    state._selectedUnits = selectedUnits;
    // state._units = units;
    state._pageTitle = 'Rezept bearbeiten';
    return state;
  }

  void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Fehler'),
          content: Text(error),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Ok'),
            ),
          ],
        );
      },
    );
  }

  String generateRandomString() {
    const uuid = Uuid();
    return uuid.v4();
  }

  @override
  void dispose() {
    _durationController.dispose();
    for (var keywordController in _keywordControllers) {
      keywordController.dispose();
    }
    super.dispose();
  }

  void _dismissKeyboard(BuildContext context) {
    // Use FocusScope to move the focus away from the TextFormField and dismiss the keyboard
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickImage(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wähle eine Bildquelle'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              GestureDetector(
                child: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _getImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                child: const Text('Galerie'),
                onTap: () {
                  Navigator.pop(context); // Close the dialog
                  _getImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedImage = await ImagePicker().pickImage(source: source);
      if (pickedImage != null) {
        Future.delayed(Duration.zero, () {
          setState(() {
            _image = File(pickedImage.path);
          });
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<String> uploadImageToFirebase(
      File? imageFile, String imageName) async {
    if (imageFile != null) {
      try {
        // Get a reference to the Firebase Storage bucket
        final firebase_storage.Reference storageRef =
            firebase_storage.FirebaseStorage.instance.ref();

        // Create a reference to the image file
        final firebase_storage.Reference imageRef = storageRef.child(imageName);

        // Upload the file to Firebase Storage
        final firebase_storage.UploadTask uploadTask =
            imageRef.putFile(imageFile);

        // Await the upload and get the download URL
        final firebase_storage.TaskSnapshot taskSnapshot =
            await uploadTask.whenComplete(() {});
        final imageUrl = await taskSnapshot.ref.getDownloadURL();

        // Return the download URL as a String
        return imageUrl;
      } catch (e) {
        print('Error uploading image: $e');
        return ''; // Return an empty string on error
      }
    }
    return '';
  }

  void _addKeywordContainer([String? keyword]) {
    TextEditingController keywordController = TextEditingController();
    if (keyword != null) {
      keywordController.text = keyword;
    } else {
      _savedKeywords.add(keywordController.text);
    }
    _keywordControllers.add(keywordController);

    Future.delayed(Duration.zero, () {
      setState(() {
        _keywordContainers.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            height: 30,
            width: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: mainColorBright,
              borderRadius: BorderRadius.circular(8),
            ),
            child: GestureDetector(
              onTap: () {
                _dismissKeyboard(context);
              },
              child: TextFormField(
                controller: keywordController,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(fontSize: 14, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Begriff',
                  hintStyle: TextStyle(color: Colors.white70, fontSize: 12),
                  border: InputBorder.none,
                ),
                onEditingComplete: () {
                  _dismissKeyboard(context);
                },
              ),
            ),
          ),
        );
      });
    });
  }

  void _removeKeywordController() {
    _keywordControllers.removeLast();
    _keywordContainers.removeLast();
    _savedKeywords.removeLast();
  }

  void _createNewIngredientController() {
    TextEditingController ingredientController = TextEditingController();
    _ingredientControllers.add(ingredientController);
  }

  void _removeIngredientController(int index) {
    _ingredientControllers.removeAt(index);
  }

  void _createNewAmountController() {
    TextEditingController amountController = TextEditingController();
    _amountControllers.add(amountController);
  }

  void _removeAmountController(int index) {
    _amountControllers.removeAt(index);
  }

  void _createNewDescriptionController() {
    TextEditingController descriptionController = TextEditingController();
    _descriptionControllers.add(descriptionController);
  }

  void _removeDescriptionController() {
    _descriptionControllers.removeLast();
  }

  void _createNewUnitValueNotifier() {
    ValueNotifier<String> valueNotifier = ValueNotifier('');
    _selectedUnits.add(valueNotifier);
  }

  void _removeUnitValueNotifier(int index) {
    _selectedUnits.removeAt(index);
  }

  void _removeUnitString(int index) {
    // _units.removeAt(index);
    _selectedUnits.removeAt(index);
  }

  void _saveSelectedUnit(String unit, int index) {
    _selectedUnits[index].value = unit;
  }

  Future<void> _saveRecipeToDatabase() async {
    CollectionReference recipesRef =
        FirebaseFirestore.instance.collection('Recipes');

    String keywords = '';
    String imageURL = '';
    List<String> description = [];
    List<Map<String, dynamic>> ingredients = [];
    int duration = 0;

    // upload image
    if (_image != null) {
      String randomImageName = generateRandomString();
      imageURL = await uploadImageToFirebase(_image, randomImageName);
    } else if (_imageUrl != '') {
      imageURL = _imageUrl;
    }

    // create keyword string
    for (var keywordController in _keywordControllers) {
      if (keywords == '') {
        keywords += keywordController.text;
      } else {
        keywords += ', ${keywordController.text}';
      }
    }

    // create description array
    for (var descriptionController in _descriptionControllers) {
      description.add(descriptionController.text);
    }

    // create ingredients array
    for (var ingredientController in _ingredientControllers) {
      int current_index = _ingredientControllers.indexOf(ingredientController);

      var ingredient = ingredientController.text;
      if (_amountControllers[current_index].text != '') {
        double amount = double.parse(_amountControllers[current_index].text);

        if (_selectedUnits.length >= current_index) {
          String unit = _selectedUnits[current_index].value;
          ingredients.add({'type': ingredient, 'amount': amount, 'unit': unit});
        } else {
          ingredients.add({'type': ingredient, 'amount': amount});
        }
      } else {
        ingredients.add({'type': ingredient});
      }
    }

    // get duration
    if (_durationController.text != '') {
      duration = int.parse(_durationController.text);
    }

    // Check if the recipe with the specified ID already exists
    recipesRef.doc(_recipeId).get().then((docSnapshot) {
      if (docSnapshot.exists) {
        // Recipe with the ID already exists, update its fields
        recipesRef.doc(_recipeId).update({
          'title': _titleController.text,
          'keywords': keywords,
          'duration': duration,
          'description': description,
          'ingredients': ingredients,
          'image': imageURL,
        }).catchError((error) {
          _showErrorDialog(context,
              'Fehler beim Hochladen des Rezepts. Bitte versuch es erneut!');
        });

        Navigator.pop(context, 'edited');
      } else {
        // Recipe with the ID doesn't exist, create a new document
        recipesRef.add({
          'title': _titleController.text,
          'keywords': keywords,
          'duration': duration,
          'description': description,
          'ingredients': ingredients,
          'image': imageURL,
        }).catchError((error) {
          _showErrorDialog(context,
              'Fehler beim Hochladen des Rezepts. Bitte versuch es erneut!');
        });

        Navigator.pop(context);
      }
    }).catchError((error) {
      print('Error checking if recipe exists: $error');
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      var tempIngredientController = _ingredientControllers[oldIndex];
      var tempAmountController = _amountControllers[oldIndex];
      var tempSelectedUnit = _selectedUnits[oldIndex];

      _ingredientControllers.removeAt(oldIndex);
      _amountControllers.removeAt(oldIndex);
      _selectedUnits.removeAt(oldIndex);

      _ingredientControllers.insert(newIndex, tempIngredientController);
      _amountControllers.insert(newIndex, tempAmountController);
      _selectedUnits.insert(newIndex, tempSelectedUnit);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_keywordControllers.isEmpty) {
      if (_savedKeywords.isEmpty) {
        _addKeywordContainer();
      } else {
        for (String keyword in _savedKeywords) {
          _addKeywordContainer(keyword);
        }
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: GestureDetector(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _image != null
                      ? Image.file(
                          _image!,
                          fit: BoxFit.cover,
                        )
                      : _imageUrl != ''
                          ? CachedNetworkImage(
                              imageUrl: _imageUrl,
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) =>
                                  const Center(child: Icon(Icons.error)),
                              fit: BoxFit.cover,
                            )
                          : Container(color: mainColorBright),
                  Container(
                      padding: const EdgeInsets.all(16.0),
                      alignment: Alignment.bottomRight,
                      child: FloatingActionButton(
                        onPressed: () => _pickImage(context),
                        backgroundColor: mainColorDark,
                        child: const Center(
                          child: Icon(
                            Icons.camera_alt,
                          ),
                        ),
                      )),
                ],
              ),
            ),
            pinned: true,
            floating: false,
            title: Text(_pageTitle),
            backgroundColor: mainColorBright,
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == 0) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        width: MediaQuery.of(context).size.width - 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                            onTap: () {
                              _dismissKeyboard(context);
                            },
                            child: TextFormField(
                                controller: _titleController,
                                minLines: 1,
                                maxLines: null,
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontSize: 16),
                                decoration: const InputDecoration(
                                  focusedBorder: UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Color(0xFF8CA095))),
                                  hintText: 'Titel',
                                  hintStyle: TextStyle(fontSize: 14),
                                ),
                                onEditingComplete: () {
                                  _dismissKeyboard(context);
                                })),
                      ),
                      const SizedBox(width: 8),
                    ]));
              } else {
                return Container();
              }
            }, childCount: 1),
          ),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        height: 30,
                        width: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: mainColorDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                            onTap: () {
                              _dismissKeyboard(context);
                            },
                            child: TextFormField(
                                controller: _durationController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(
                                      r'^\d+([,.]?\d{0,2})?$')), // Allow numbers with up to 2 decimal places
                                ],
                                textAlign: TextAlign.center,
                                textAlignVertical: TextAlignVertical.center,
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Zeit',
                                  hintStyle: TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                  border: InputBorder.none,
                                ),
                                onEditingComplete: () {
                                  _dismissKeyboard(context);
                                }))),
                    ..._keywordContainers,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 3),
                      height: 30,
                      width: 30,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          _dismissKeyboard(context);
                          _addKeywordContainer();
                        },
                        child: FloatingActionButton(
                          heroTag: generateRandomString(),
                          elevation: 0.0,
                          onPressed: () {
                            _addKeywordContainer();
                          },
                          backgroundColor: mainColorBright,
                          child: const Center(child: Icon(Icons.add)),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 3),
                      height: 30,
                      width: 30,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          _dismissKeyboard(context);
                          // _removeKeywordContainer();
                        },
                        child: FloatingActionButton(
                          heroTag: generateRandomString(),
                          elevation: 0.0,
                          onPressed: () {
                            Future.delayed(Duration.zero, () {
                              setState(() {
                                _removeKeywordController();
                              });
                            });
                          },
                          backgroundColor: mainColorBright,
                          child: const Center(child: Icon(Icons.remove)),
                        ),
                      ),
                    )
                  ]))),
          const SliverToBoxAdapter(
              child: Padding(
                  key: ValueKey("header"),
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8),
                        Text('Zutaten',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ]))),
          SliverReorderableList(
              itemBuilder: (context, index) {
                if (_ingredientControllers.isEmpty) {
                  _createNewIngredientController();
                  _createNewAmountController();
                  _createNewUnitValueNotifier();
                }

                if (index <= (_ingredientControllers.length)) {
                  return Material(
                      key: ValueKey(index),
                      child: ReorderableDelayedDragStartListener(
                          key: ValueKey(index),
                          index: index,
                          child: Padding(
                              key: ValueKey(index),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(children: [
                                // const Icon(Icons.reorder),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 3),
                                  height: 35,
                                  width: 160,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: GestureDetector(
                                      onTap: () {
                                        _dismissKeyboard(context);
                                      },
                                      child: TextFormField(
                                          controller:
                                              _ingredientControllers[index],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16),
                                          decoration: const InputDecoration(
                                            focusedBorder: UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Color(0xFF8CA095))),
                                            hintText: 'Zutat',
                                            hintStyle: TextStyle(fontSize: 14),
                                          ),
                                          onEditingComplete: () {
                                            _dismissKeyboard(context);
                                          })),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  height: 35,
                                  width: 80,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: GestureDetector(
                                      onTap: () {
                                        _dismissKeyboard(context);
                                      },
                                      child: TextFormField(
                                          controller: _amountControllers[index],
                                          keyboardType: TextInputType
                                              .number, // This will display a numeric keyboard
                                          inputFormatters: [
                                            FilteringTextInputFormatter.allow(
                                                RegExp(
                                                    r'^\d+([,.]?\d{0,2})?$')), // Allow numbers with up to 2 decimal places
                                          ],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16),
                                          decoration: const InputDecoration(
                                            focusedBorder: UnderlineInputBorder(
                                                borderSide: BorderSide(
                                                    color: Color(0xFF8CA095))),
                                            hintText: 'Menge',
                                            hintStyle: TextStyle(fontSize: 14),
                                          ),
                                          onEditingComplete: () {
                                            _dismissKeyboard(context);
                                          })),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  height: 35,
                                  width: 68,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: UnitDropdownMenu(
                                    index: index,
                                    selectedItem: _selectedUnits[index],
                                    onItemSelected: _saveSelectedUnit,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 3),
                                  height: 35,
                                  width: 35,
                                  alignment: Alignment.center,
                                  child: GestureDetector(
                                    onTap: () {
                                      _dismissKeyboard(context);
                                    },
                                    child: FloatingActionButton(
                                      heroTag: generateRandomString(),
                                      elevation: 0.0,
                                      onPressed: () {
                                        Future.delayed(Duration.zero, () {
                                          setState(() {
                                            _removeIngredientController(index);
                                            _removeAmountController(index);
                                            _removeUnitValueNotifier(index);
                                          });
                                        });
                                      },
                                      backgroundColor: mainColorBright,
                                      child: const Center(
                                          child: Icon(Icons.remove)),
                                    ),
                                  ),
                                ),
                              ]))));
                } else {
                  return Container();
                }
              },
              itemCount: _ingredientControllers.length,
              onReorder: _onReorder),
          SliverToBoxAdapter(
              child: Padding(
                  key: const ValueKey("addButton"),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 3),
                        height: 35,
                        width: 35,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () {
                            _dismissKeyboard(context);
                          },
                          child: FloatingActionButton(
                            heroTag: generateRandomString(),
                            elevation: 0.0,
                            onPressed: () {
                              Future.delayed(Duration.zero, () {
                                setState(() {
                                  _createNewAmountController();
                                  _createNewIngredientController();
                                  _createNewUnitValueNotifier();
                                });
                              });
                            },
                            backgroundColor: mainColorBright,
                            child: const Center(child: Icon(Icons.add)),
                          ),
                        ),
                      ),
                    ],
                  ))),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (_descriptionControllers.isEmpty) {
                _createNewDescriptionController();
              }

              if (index == 0) {
                return const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8),
                          Text('Beschreibung',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ]));
              } else if (index <= (_descriptionControllers.length)) {
                var currentIndex = index - 1;
                TextEditingController descriptionController =
                    _descriptionControllers[currentIndex];

                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        width: MediaQuery.of(context).size.width - 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                            onTap: () {
                              _dismissKeyboard(context);
                            },
                            child: TextFormField(
                                controller: descriptionController,
                                minLines: 1,
                                maxLines: null,
                                textAlign: TextAlign.left,
                                style: const TextStyle(fontSize: 16),
                                decoration: InputDecoration(
                                  focusedBorder: const UnderlineInputBorder(
                                      borderSide:
                                          BorderSide(color: Color(0xFF8CA095))),
                                  hintText: 'Schritt ${currentIndex + 1}',
                                  hintStyle: const TextStyle(fontSize: 14),
                                ),
                                onEditingComplete: () {
                                  _dismissKeyboard(context);
                                })),
                      ),
                      const SizedBox(width: 8),
                    ]));
              } else if (index == _descriptionControllers.length + 1) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 3),
                          height: 35,
                          width: 35,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              _dismissKeyboard(context);
                            },
                            child: FloatingActionButton(
                              heroTag: generateRandomString(),
                              elevation: 0.0,
                              onPressed: () {
                                Future.delayed(Duration.zero, () {
                                  setState(() {
                                    _createNewDescriptionController();
                                  });
                                });
                              },
                              backgroundColor: mainColorBright,
                              child: const Center(child: Icon(Icons.add)),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 3),
                          height: 35,
                          width: 35,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: () {
                              _dismissKeyboard(context);
                            },
                            child: FloatingActionButton(
                              heroTag: generateRandomString(),
                              elevation: 0.0,
                              onPressed: () {
                                Future.delayed(Duration.zero, () {
                                  setState(() {
                                    _removeDescriptionController();
                                  });
                                });
                              },
                              backgroundColor: mainColorBright,
                              child: const Center(child: Icon(Icons.remove)),
                            ),
                          ),
                        ),
                      ],
                    ));
              } else {
                return Container();
              }
            }, childCount: _descriptionControllers.length + 3),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<void>(
        future: _savingRecipe ? _saveRecipeToDatabase() : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a loading indicator while waiting for the save operation to complete
            return Container(
              height: 60,
              alignment: Alignment.bottomRight,
              child: CircularProgressIndicator(color: mainColorBright),
            );
          } else {
            return Container(
              height: 60,
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                heroTag: generateRandomString(),
                onPressed: () async {
                  if (_titleController.text == '') {
                    _showErrorDialog(context,
                        'Bitte gib einen Titel für das Rezept an bevor du es speicherst!');
                  } else {
                    Future.delayed(Duration.zero, () {
                      setState(() {
                        _savingRecipe = true;
                      });
                    });
                  }
                },
                backgroundColor: mainColorBright,
                child: const Center(child: Icon(Icons.check)),
              ),
            );
          }
        },
      ),
    );
  }
}

class EditRecipeScreen extends StatelessWidget {
  const EditRecipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Recipe'),
      ),
      body: const Center(
        child: Text('Edit Recipe Form'),
      ),
    );
  }
}

class CustomAppBar extends StatefulWidget {
  final ValueChanged<String> onSearchQueryChanged;

  const CustomAppBar({
    Key? key,
    required this.onSearchQueryChanged,
  }) : super(key: key);

  @override
  _CustomAppBarState createState() => _CustomAppBarState();
}

class _CustomAppBarState extends State<CustomAppBar> {
  bool _showSearchBar = true;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          border: const Border(
            bottom: BorderSide(
              color: Color(0xFF2F5942),
              width: 3.0,
            ),
          ),
        ),
        child: SafeArea(
            child: Center(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSearchBar = !_showSearchBar;
                      });
                    },
                    child: Visibility(
                        visible: _showSearchBar,
                        replacement: SizedBox(
                          height: 50,
                          child: TextFormField(
                            textAlignVertical: TextAlignVertical.center,
                            onChanged: widget.onSearchQueryChanged,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.all(16.0),
                              hintText: 'Suche nach Rezepten...',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Rezepte',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )),
                  ),
                ),
                IconButton(
                  icon: const Center(
                      child: Icon(
                    Icons.search,
                    color: Colors.white,
                  )),
                  onPressed: () {
                    setState(() {
                      _showSearchBar = !_showSearchBar;

                      if (_showSearchBar) {
                        widget.onSearchQueryChanged('');
                      }
                    });
                  },
                ),
                // const SizedBox(width: 8.0),
              ],
            ),
          ),
        )));
  }
}

class ImageDialog extends StatelessWidget {
  final String imageUrl;

  const ImageDialog({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        color: Colors.transparent,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) =>
              const Center(child: Icon(Icons.camera_alt)),
        ),
      ),
    );
  }
}

class RecipeListView extends StatelessWidget {
  final String searchQuery;

  RecipeListView({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Recipes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final recipeDocs = snapshot.data?.docs ?? [];

        final filteredRecipes = [];
        for (var recipeDoc in recipeDocs) {
          var recipeData = recipeDoc.data() as Map<String, dynamic>;
          var recipe = Recipe(
            recipeDoc.id,
            recipeData['title'],
            recipeData['image'],
            recipeData['keywords'],
            recipeData['duration'],
            recipeData['description'],
            recipeData['ingredients'],
          );
          if (recipe.title.toLowerCase().contains(searchQuery.toLowerCase())) {
            filteredRecipes.add(recipe);
          }
        }

        return ListView.builder(
          itemCount: filteredRecipes.length,
          itemBuilder: (context, index) {
            final recipe = filteredRecipes[index];

            List<String> keywordList = [];
            if (recipe.keywords != '') {
              keywordList = recipe.keywords.split(', ');
            }

            return ListTile(
              leading: ClipRect(
                child: CachedNetworkImage(
                  imageUrl: recipe.imageUrl,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(),
                  errorWidget: (context, url, error) =>
                      const Center(child: Icon(Icons.camera_alt)),
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(recipe.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              subtitle: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: mainColorDark,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      recipe.duration.toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ...keywordList.map((keyword) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: mainColorBright,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          keyword,
                          style: const TextStyle(color: Colors.black),
                        ),
                      )),
                ],
              ),
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        RecipeDetailsScreen(recipe: recipe),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1, 0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;

                      var tween = Tween(begin: begin, end: end)
                          .chain(CurveTween(curve: curve));

                      var offsetAnimation = animation.drive(tween);

                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class RecipeDetailsScreen extends StatefulWidget {
  final Recipe recipe;

  RecipeDetailsScreen({Key? key, required this.recipe}) : super(key: key);

  @override
  _RecipeDetailsScreenState createState() =>
      _RecipeDetailsScreenState(recipe: recipe);
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  Recipe recipe;
  List<String> _keywords = [];
  int _numberOfPortions = 2;

  _RecipeDetailsScreenState({required this.recipe});

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchRecipe() async {
    try {
      return await FirebaseFirestore.instance
          .collection('Recipes')
          .doc(recipe.id)
          .get();
    } catch (error) {
      print('Error fetching recipe: $error');
      rethrow; // Rethrow the error to handle it higher up the tree if needed
    }
  }

  String generateRandomString() {
    const uuid = Uuid();
    return uuid.v4();
  }

  void _deleteRecipeFromDatabase() {
    FirebaseFirestore.instance.collection('Recipes').doc(recipe.id).delete();
  }

  String trimFloat(double? number) {
    if (number != null) {
      String result =
          number.toStringAsFixed(2); // Convert to string with 1 decimal place
      RegExp regex = RegExp(r'\.\d*0$');

      if (result.endsWith('.00')) {
        // If the string ends with '.0', remove it
        result = result.substring(0, result.length - 3);
      } else if (regex.hasMatch(result)) {
        result = result.substring(0, result.length - 1);
      }
      return result;
    } else {
      return '';
    }
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rezept löschen'),
          content: const Text('Willst du dieses Rezept endgültig löschen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Abbrechen'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Löschen'),
              onPressed: () {
                _deleteRecipeFromDatabase();

                Navigator.pushNamedAndRemoveUntil(
                    context, '/', (Route<dynamic> route) => false);
              },
            ),
          ],
        );
      },
    );
  }

  void _increaseNumberOfPortions() {
    int oldNumberOfPortions = _numberOfPortions;
    _numberOfPortions += 1;
    _calculateIngredientAmounts(oldNumberOfPortions);
  }

  void _decreaseNumberOfPortions() {
    if (_numberOfPortions > 1) {
      int oldNumberOfPortions = _numberOfPortions;
      _numberOfPortions -= 1;
      _calculateIngredientAmounts(oldNumberOfPortions);
    }
  }

  void _calculateIngredientAmounts(int oldNumberOfPortions) {
    setState(() {
      for (int index = 0; index < recipe.ingredients.length; index++) {
        if (recipe.ingredients[index]['amount'] == null) {
          continue;
        }
        double newAmount = recipe.ingredients[index]['amount'] /
            oldNumberOfPortions *
            _numberOfPortions;
        recipe.ingredients[index]['amount'] = newAmount;
      }
    });
  }

  void _resetIngredientAmounts(int oldNumberOfPortions) {
    _numberOfPortions = 2;
    for (int index = 0; index < recipe.ingredients.length; index++) {
      if (recipe.ingredients[index]['amount'] == null) {
        continue;
      }
      double newAmount =
          recipe.ingredients[index]['amount'] / oldNumberOfPortions * 2;
      recipe.ingredients[index]['amount'] = newAmount;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (recipe.keywords != '') {
      _keywords = recipe.keywords.split(', ');
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => ImageDialog(imageUrl: recipe.imageUrl),
                );
              },
              child: CachedNetworkImage(
                placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                errorWidget: (context, url, error) =>
                    const Center(child: Icon(Icons.camera_alt)),
                imageUrl: recipe.imageUrl,
                fit: BoxFit.cover,
              ),
            )),
            pinned:
                true, // The app bar will be pinned at the top while scrolling
            floating: false,
            title: Text(recipe.title, overflow: TextOverflow.ellipsis),
            backgroundColor: mainColorBright,
            actions: [
              IconButton(
                  onPressed: () {
                    _showDeleteConfirmationDialog(context);
                  },
                  icon: const Center(child: Icon(Icons.delete)))
            ],
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: mainColorDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recipe.duration.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        ..._keywords.map(
                          (keyword) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: mainColorBright,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              keyword,
                              style: const TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (index == 1) {
                  List<TableRow> ingredientRows = [];
                  for (var ingredient in recipe.ingredients) {
                    final type = ingredient['type'];
                    final amount = trimFloat(ingredient['amount']);
                    final unit = ingredient['unit'];

                    String amountAndUnit = '';

                    if (amount != '' && unit != null) {
                      if (unit != 'piece') {
                        amountAndUnit = '$amount $unit';
                      } else {
                        amountAndUnit = '$amount';
                      }
                    }

                    ingredientRows.add(
                      TableRow(
                        children: [
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 1.0),
                              child: Row(children: [
                                const Center(
                                    child: Icon(
                                  Icons.circle,
                                  color: Color(0xFF8CA095),
                                  size: 14,
                                )),
                                const SizedBox(width: 8),
                                Text(type,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(fontSize: 16))
                              ])),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Text(
                              amountAndUnit,
                              textAlign: TextAlign.left,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Return the ingredient table wrapped in a ListView for scrolling
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(0, 6, 0, 0),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Divider(
                            color: Color(
                                0xFF2F5942), // Color of the separator line
                            thickness: 2.0, // Adjust the thickness as needed
                          )),
                      Row(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                          child: Text(
                            _numberOfPortions == 1
                                ? 'Zutaten für $_numberOfPortions Portion'
                                : 'Zutaten für $_numberOfPortions Portionen',
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                            height: 25,
                            width: 25,
                            child: FloatingActionButton(
                              heroTag: generateRandomString(),
                              elevation: 0.0,
                              backgroundColor: mainColorBright,
                              onPressed: _increaseNumberOfPortions,
                              child: const Icon(Icons.add),
                            )),
                        const SizedBox(width: 6),
                        SizedBox(
                            height: 25,
                            width: 25,
                            child: FloatingActionButton(
                              heroTag: generateRandomString(),
                              elevation: 0.0,
                              backgroundColor: mainColorBright,
                              onPressed: _decreaseNumberOfPortions,
                              child: const Icon(Icons.remove),
                            )),
                      ]),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Table(
                              columnWidths: const {0: FractionColumnWidth(0.6)},
                              children: ingredientRows,
                            ),
                            const Divider(
                              color: Color(
                                  0xFF2F5942), // Color of the separator line
                              thickness: 2.0, // Adjust the thickness as needed
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else if (index == 2) {
                  return const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: Text(
                        'Beschreibung',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ));
                } else {
                  final descriptionIndex = index - 3;
                  if (descriptionIndex < recipe.description.length) {
                    final prefix = 'Schritt ${descriptionIndex + 1}: ';
                    final descriptionItem =
                        '$prefix${recipe.description[descriptionIndex]}';
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(descriptionItem,
                          style: const TextStyle(fontSize: 16)),
                    );
                  } else {
                    return Container(); // Empty container for safety
                  }
                }
              },
              childCount:
                  3 + recipe.description.length, // Number of items in the list
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) {
              _resetIngredientAmounts(_numberOfPortions);
              return AddRecipeScreen.withValues(recipe);
            }),
          );

          if (result != null && result == 'edited') {
            final updatedRecipe = await fetchRecipe();
            setState(() {
              recipe = Recipe(
                  updatedRecipe.id,
                  updatedRecipe['title'],
                  updatedRecipe['image'],
                  updatedRecipe['keywords'],
                  updatedRecipe['duration'],
                  updatedRecipe['description'],
                  updatedRecipe['ingredients']);
            });
          }
        },
        backgroundColor: mainColorBright,
        child: const Center(child: Icon(Icons.edit)),
      ),
    );
  }
}
