import 'package:flutter/material.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/providers/word_state_provider.dart';
import 'package:provider/provider.dart';

// ***** 确保类名是 DetailTabs *****
class DetailTabs extends StatelessWidget {
  const DetailTabs({Key? key}) : super(key: key);
  // ------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTab =
        context.select((WordStateProvider p) => p.selectedDetailTab);
    final wordState = Provider.of<WordStateProvider>(context, listen: false);

    final List<Map<String, dynamic>> tabs = [
      {
        'icon': Icons.translate_rounded,
        'label': '释义',
        'stage': WordDisplayStage.definition
      },
      {
        'icon': Icons.menu_book_rounded,
        'label': '例句',
        'stage': WordDisplayStage.sentence
      },
      {
        'icon': Icons.format_list_bulleted_rounded,
        'label': '短语',
        'stage': WordDisplayStage.phrase
      },
      {
        'icon': Icons.compare_arrows_rounded,
        'label': '近义',
        'stage': WordDisplayStage.synonym
      },
      {
        'icon': Icons.account_tree_rounded,
        'label': '同根',
        'stage': WordDisplayStage.related
      },
    ];

    return Container(
      height: 56,
      // 背景透明
      child: Row(
        children: tabs.map((tabData) {
          final bool isSelected = selectedTab == tabData['stage'];
          final Color activeColor = theme.colorScheme.primary;
          final Color inactiveColor = theme.colorScheme.onSurfaceVariant;

          return Expanded(
            child: InkWell(
              onTap: () => wordState.selectDetailTab(tabData['stage']),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tabData['icon'],
                    color: isSelected ? activeColor : inactiveColor,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tabData['label'],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isSelected ? activeColor : inactiveColor,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    height: 2.0,
                    width: 32.0,
                    color: isSelected ? activeColor : Colors.transparent,
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
