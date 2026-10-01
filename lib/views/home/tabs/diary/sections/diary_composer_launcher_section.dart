part of '../../diary_tab.dart';

class _DiaryComposerLauncherSection extends StatelessWidget {
  final _DiaryTabState state;

  const _DiaryComposerLauncherSection({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: CustomMoodStickerService.instance.customStickerUrlVN,
      builder: (context, customUrl, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: state._composerState.isPostingVN,
          builder: (context, isPosting, child) {
            return ValueListenableBuilder<String>(
              valueListenable: state._composerState.selectedMoodVN,
              builder: (context, selectedMood, child) {
                return DiaryComposer(
                  houseId: state._houseId ?? '',
                  moods: state._composerState.getMoodsWithCustom(customUrl),
                  selectedMood: selectedMood,
                  onMoodChanged: state._composerState.setMood,
                  composerController: state._composerState.textController,
                  isPostingDiary: isPosting,
                  onSubmit: state._submitDiaryPost,
                );
              },
            );
          },
        );
      },
    );
  }
}
