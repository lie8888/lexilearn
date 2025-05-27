import 'package:flutter/material.dart';
import 'package:lexilearn/constants.dart';
import 'package:lexilearn/models/word_entry.dart';
import 'package:lexilearn/providers/word_state_provider.dart';
import 'package:provider/provider.dart';

// ***** 确保类名是 DetailContent *****
class DetailContent extends StatelessWidget {
  final WordEntry wordEntry;

  const DetailContent({Key? key, required this.wordEntry}) : super(key: key);
  // --------------------------------

  Widget _buildNoInfo(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text("暂无 $title 信息",
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final selectedTab =
        context.select((WordStateProvider p) => p.selectedDetailTab);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300), // 使用上次修正的时长
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Container(
        key: ValueKey<WordDisplayStage>(selectedTab),
        alignment: Alignment.topLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          // 直接返回 Column
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [_buildContentForStage(context, selectedTab)],
        ),
      ),
    );
  }

  Widget _buildContentForStage(BuildContext context, WordDisplayStage stage) {
    // ... (内部逻辑和样式使用 Reply #39 的最终修正版) ...
    final theme = Theme.of(context);
    final details = wordEntry.content.word.content;

    const defaultTextStyle = TextStyle(fontSize: 14, height: 1.5);
    final titleStyle = (theme.textTheme.headlineMedium ??
            defaultTextStyle.copyWith(fontSize: 22))
        .copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.primary,
      height: 1.4,
    );
    final primaryEnglishStyle =
        (theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
      fontWeight: FontWeight.bold,
      color: onSurfaceColor,
      height: 1.5,
    );
    final secondaryChineseStyle =
        (theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16)).copyWith(
      color: onSurfaceVariantColor,
      height: 1.5,
    );
    final posStyle = (theme.textTheme.bodyMedium ?? defaultTextStyle).copyWith(
      color: onPrimaryContainerColor,
      fontWeight: FontWeight.bold,
      height: 1.5,
    ); // 使用 onPrimaryContainerColor
    final chineseBoldStyle =
        (theme.textTheme.bodyLarge ?? defaultTextStyle.copyWith(fontSize: 16))
            .copyWith(
      color: onSurfaceVariantColor,
      height: 1.5,
      fontWeight: FontWeight.w600,
    );
    final engMeaningStyle =
        (theme.textTheme.bodyLarge ?? defaultTextStyle.copyWith(fontSize: 16))
            .copyWith(height: 1.5, color: onSurfaceColor);

    Widget buildListItem(String primary, String? secondary,
        {TextStyle? primaryStyle, TextStyle? secondaryStyle, String? pos}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pos != null && pos.isNotEmpty) ...[
              Text(pos, style: posStyle),
              const SizedBox(height: 4),
            ],
            Text(primary, style: primaryStyle ?? primaryEnglishStyle),
            if (secondary != null && secondary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(secondary, style: secondaryStyle ?? secondaryChineseStyle),
            ]
          ],
        ),
      );
    }

    Widget buildGroupList<T>(
        String title, List<T> items, Widget Function(T item) itemBuilder) {
      if (items.isEmpty) {
        return _buildNoInfo(context, title);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
            child: Text(title, style: titleStyle),
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map(itemBuilder).toList()),
        ],
      );
    }

    switch (stage) {
      case WordDisplayStage.definition:
        return buildGroupList<Tran>(
            "单词释义:",
            details.trans,
            (Tran t) => buildListItem(
                  t.tranOther.isNotEmpty ? t.tranOther : "(no definition)",
                  t.tranCn,
                  pos: "${t.pos}.",
                  primaryStyle: engMeaningStyle,
                  secondaryStyle: chineseBoldStyle,
                ));
      case WordDisplayStage.sentence:
        return buildGroupList<Sentence>("例句:", details.sentence.sentences,
            (Sentence s) => buildListItem(s.sContent, s.sCn));
      case WordDisplayStage.phrase:
        return buildGroupList<Phrase>("短语:", details.phrase.phrases,
            (Phrase p) => buildListItem(p.pContent, p.pCn));
      case WordDisplayStage.synonym:
        if (details.syno.synos.isEmpty) {
          return _buildNoInfo(context, "近义词");
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
              child: Text("近义词:", style: titleStyle),
            ),
            ...details.syno.synos.map((Synonym s) {
              final words = s.hwds.map((h) => h.w).join(', ');
              return buildListItem(
                words.isNotEmpty ? words : "(无)",
                s.tran,
                pos: "${s.pos}.",
                primaryStyle: primaryEnglishStyle,
              );
            }).toList(),
          ],
        );
      case WordDisplayStage.related:
        if (details.relWord.rels.isEmpty) {
          return _buildNoInfo(context, "同根词");
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
              child: Text("同根词:", style: titleStyle),
            ),
            ...details.relWord.rels.map((RelWord r) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.pos.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Text("${r.pos}.", style: posStyle),
                    ),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: r.words.map((WordInfo w) {
                        return buildListItem(w.hwd, w.tran.trim(),
                            primaryStyle: primaryEnglishStyle);
                      }).toList()),
                ],
              );
            }).toList(),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
