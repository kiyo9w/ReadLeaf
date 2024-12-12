import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Assuming these widgets and pages exist in your project:
import '../widgets/snack_bar_widget.dart';
import '../blocs/FileBloc/file_bloc.dart';
import 'results_page.dart';
import '../widgets/page_title_widget.dart';

// Example dropdown data (adjust as needed)
final Map<String, String> typeValues = {
  'All': '',
  'Any Books': 'book_any',
  'Unknown Books': 'book_unknown',
  'Fiction Books': 'book_fiction',
  'Non-fiction Books': 'book_nonfiction',
  'Comic Books': 'book_comic',
  'Magazine': 'magazine',
  'Standards Document': 'standards_document',
  'Journal Article': 'journal_article'
};

final Map<String, String> sortValues = {
  'Most Relevant': '',
  'Newest': 'newest',
  'Oldest': 'oldest',
  'Largest': 'largest',
  'Smallest': 'smallest',
};

final List<String> fileType = ["All", "PDF", "Epub", "Cbr", "Cbz"];

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  String searchQuery = "";
  String selectedType = "All";
  String selectedSort = "Most Relevant";
  String selectedFileType = "All";

  void onSubmit(BuildContext context) {
    if (searchQuery.isNotEmpty) {
      final fileBloc = BlocProvider.of<FileBloc>(context);
      fileBloc.add(SearchBooks(
        query: searchQuery,
        content: typeValues[selectedType] ?? '',
        sort: sortValues[selectedSort] ?? '',
        fileType: selectedFileType == "All" ? '' : selectedFileType.toLowerCase(),
        enableFilters: true,
      ));
    } else {
      showSnackBar(context: context, message: 'Search field is empty');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FileBloc, FileState>(
      listener: (context, state) {
        if (state is FileSearchResults) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (BuildContext context) {
                return ResultPage(searchQuery: searchQuery);
              },
            ),
          );
        } else if (state is FileError) {
          showSnackBar(context: context, message: state.message);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TitleText("Search"),
                  Padding(
                    padding: const EdgeInsets.only(left: 7, right: 7, top: 10),
                    child: TextField(
                      showCursor: true,
                      cursorColor: Colors.grey,
                      decoration: InputDecoration(
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey, width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.all(Radius.circular(50)),
                        ),
                        suffixIcon: IconButton(
                          padding: const EdgeInsets.only(right: 5),
                          color: Colors.black,
                          icon: const Icon(Icons.search, size: 23),
                          onPressed: () => onSubmit(context),
                        ),
                        filled: true,
                        hintStyle: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: "Search",
                        fillColor: Colors.white,
                      ),
                      onSubmitted: (String value) => onSubmit(context),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onChanged: (String value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 7, right: 7, top: 19),
                    child: SizedBox(
                      width: 250,
                      child: DropdownButtonFormField(
                        decoration: const InputDecoration(
                          labelText: 'Type',
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_drop_down),
                        value: selectedType,
                        items: typeValues.keys
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style:
                              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? val) {
                          setState(() {
                            selectedType = val ?? 'All';
                          });
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 7, right: 7, top: 19),
                    child: SizedBox(
                      width: 210,
                      child: DropdownButtonFormField(
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                        value: selectedSort,
                        items: sortValues.keys
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style:
                              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? val) {
                          setState(() {
                            selectedSort = val ?? 'Most Relevant';
                          });
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 7, right: 7, top: 19),
                    child: SizedBox(
                      width: 165,
                      child: DropdownButtonFormField(
                        decoration: const InputDecoration(
                          labelText: 'File type',
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey, width: 2),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.all(Radius.circular(50)),
                          ),
                        ),
                        value: selectedFileType,
                        items: fileType.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style:
                              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? val) {
                          setState(() {
                            selectedFileType = val ?? 'All';
                          });
                        },
                      ),
                    ),
                  ),
                  if (state is FileSearchLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}