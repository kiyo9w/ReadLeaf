import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/snack_bar_widget.dart';
import '../blocs/FileBloc/file_bloc.dart';
import 'results_page.dart';

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
        fileType:
        selectedFileType == "All" ? '' : selectedFileType.toLowerCase(),
        enableFilters: true,
      ));
    } else {
      showSnackBar(context: context, message: 'Search field is empty');
    }
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filters",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField(
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? val) {
                    setState(() {
                      selectedType = val ?? 'All';
                    });
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField(
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
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? val) {
                    setState(() {
                      selectedSort = val ?? 'Most Relevant';
                    });
                  },
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField(
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
                  items: fileType
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? val) {
                    setState(() {
                      selectedFileType = val ?? 'All';
                    });
                  },
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopSearches() {
    // Hard-coded placeholders for "Top searches"
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Text(
            'Top searches',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // Hard-coded search items
        ListTile(
          title: Text('Coffee shop'),
          subtitle: Text('CopyCat - 2023: A book about a coffee shop'),
          onTap: () {},
        ),
        Divider(),
        ListTile(
          title: Text('Human nature'),
          subtitle: Text('Jessie Nor - 2013: Explore the human nature'),
          onTap: () {},
        ),
        Divider(),
        ListTile(
          title: Text('In Cold Blood'),
          subtitle: Text('Truman Capote - 1999: A book a shop'),
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildTrending() {
    // Hard-coded placeholders for "Trending"
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 20.0),
          child: Text(
            'Trending',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        // Just a row of placeholder categories
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCategoryCard('Fiction', 'A New Dawn'),
                SizedBox(width: 10),
                _buildCategoryCard('Novel', 'Some Book'),
                SizedBox(width: 10),
                _buildCategoryCard('Non-fiction', 'Great Journey'),
                SizedBox(width: 10),
                _buildCategoryCard('Romance', 'All This'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(String category, String title) {
    return Container(
      width: 160,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade300,
        image: DecorationImage(
          // hard code
          image: AssetImage('/Users/ngotrung/StudioProjects/migrated/lib/assets/images/56916837.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 5,
            left: 5,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: Colors.black54,
              child: Text(
                category,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
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
          backgroundColor: Colors.white,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 10),
              child: AppBar(
                backgroundColor: Colors.white,
                centerTitle: false,
                title: const Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 42.0,
                  ),
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search bar with filter icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            padding: const EdgeInsets.only(right: 5),
                            color: Colors.black,
                            icon: const Icon(Icons.search, size: 23),
                            onPressed: () => onSubmit(context),
                          ),
                          Expanded(
                            child: TextField(
                              showCursor: true,
                              cursorColor: Colors.grey,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                                border: InputBorder.none,
                                hintText: "Find some books...",
                                hintStyle: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onSubmitted: (String value) => onSubmit(context),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              onChanged: (String value) {
                                setState(() {
                                  searchQuery = value;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showFilterModal(context),
                            icon: const Icon(Icons.filter_list),
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),

                  _buildTopSearches(),

                  _buildTrending(),

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