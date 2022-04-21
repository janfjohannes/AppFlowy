import 'dart:collection';
import 'package:app_flowy/workspace/application/grid/cell/selection_editor_bloc.dart';
import 'package:app_flowy/workspace/application/grid/row/row_service.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/layout/sizes.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/widgets/header/type_option/edit_option_pannel.dart';
import 'package:app_flowy/workspace/presentation/plugins/grid/src/widgets/header/type_option/widget.dart';
import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/hover.dart';
import 'package:flowy_infra_ui/style_widget/icon_button.dart';
import 'package:flowy_infra_ui/style_widget/scrolling/styled_list.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flowy_sdk/protobuf/flowy-grid/selection_type_option.pb.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:app_flowy/generated/locale_keys.g.dart';
import 'package:textfield_tags/textfield_tags.dart';

import 'extension.dart';
import 'text_field.dart';

const double _editorPannelWidth = 300;

class SelectOptionCellEditor extends StatelessWidget with FlowyOverlayDelegate {
  final GridCell cellData;
  final List<SelectOption> options;
  final List<SelectOption> selectedOptions;
  final VoidCallback onDismissed;

  const SelectOptionCellEditor({
    required this.cellData,
    required this.options,
    required this.selectedOptions,
    required this.onDismissed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SelectOptionEditorBloc(
        cellData: cellData,
        options: options,
        selectedOptions: selectedOptions,
      )..add(const SelectOptionEditorEvent.initial()),
      child: BlocBuilder<SelectOptionEditorBloc, SelectOptionEditorState>(
        builder: (context, state) {
          return CustomScrollView(
            shrinkWrap: true,
            slivers: [
              SliverToBoxAdapter(child: _TextField()),
              const SliverToBoxAdapter(child: VSpace(6)),
              const SliverToBoxAdapter(child: TypeOptionSeparator()),
              const SliverToBoxAdapter(child: VSpace(6)),
              const SliverToBoxAdapter(child: _Title()),
              const SliverToBoxAdapter(child: _OptionList()),
            ],
          );
        },
      ),
    );
  }

  static void show(
    BuildContext context,
    GridCell cellData,
    List<SelectOption> options,
    List<SelectOption> selectedOptions,
    VoidCallback onDismissed,
  ) {
    SelectOptionCellEditor.remove(context);
    final editor = SelectOptionCellEditor(
      cellData: cellData,
      options: options,
      selectedOptions: selectedOptions,
      onDismissed: onDismissed,
    );

    //
    FlowyOverlay.of(context).insertWithAnchor(
      widget: OverlayContainer(
        child: SizedBox(width: _editorPannelWidth, child: editor),
        constraints: BoxConstraints.loose(const Size(_editorPannelWidth, 300)),
      ),
      identifier: SelectOptionCellEditor.identifier(),
      anchorContext: context,
      anchorDirection: AnchorDirection.bottomWithCenterAligned,
      delegate: editor,
    );
  }

  static void remove(BuildContext context) {
    FlowyOverlay.of(context).remove(identifier());
  }

  static String identifier() {
    return (SelectOptionCellEditor).toString();
  }

  @override
  bool asBarrier() => true;

  @override
  void didRemove() => onDismissed();
}

class _OptionList extends StatelessWidget {
  const _OptionList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectOptionEditorBloc, SelectOptionEditorState>(
      builder: (context, state) {
        final cells = state.options.map((option) {
          return _SelectOptionCell(option, state.selectedOptions.contains(option));
        }).toList();
        final list = ListView.separated(
          shrinkWrap: true,
          controller: ScrollController(),
          itemCount: cells.length,
          separatorBuilder: (context, index) {
            return VSpace(GridSize.typeOptionSeparatorHeight);
          },
          physics: StyledScrollPhysics(),
          itemBuilder: (BuildContext context, int index) {
            return cells[index];
          },
        );
        return list;
      },
    );
  }
}

class _TextField extends StatelessWidget {
  final TextfieldTagsController _tagController = TextfieldTagsController();

  _TextField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SelectOptionEditorBloc, SelectOptionEditorState>(
      builder: (context, state) {
        final optionMap = LinkedHashMap<String, SelectOption>.fromIterable(state.selectedOptions,
            key: (option) => option.name, value: (option) => option);

        return SizedBox(
          height: 42,
          child: SelectOptionTextField(
            options: state.options,
            selectedOptionMap: optionMap,
            distanceToText: _editorPannelWidth * 0.7,
            tagController: _tagController,
            onNewTag: (tagName) {
              context.read<SelectOptionEditorBloc>().add(SelectOptionEditorEvent.newOption(tagName));
            },
          ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return SizedBox(
      height: GridSize.typeOptionItemHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: FlowyText.medium(
          LocaleKeys.grid_selectOption_pannelTitle.tr(),
          fontSize: 12,
          color: theme.shader3,
        ),
      ),
    );
  }
}

class _SelectOptionCell extends StatelessWidget {
  final SelectOption option;
  final bool isSelected;
  const _SelectOptionCell(this.option, this.isSelected, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return SizedBox(
      height: GridSize.typeOptionItemHeight,
      child: InkWell(
        onTap: () {
          context.read<SelectOptionEditorBloc>().add(SelectOptionEditorEvent.selectOption(option.id));
        },
        child: FlowyHover(
          style: HoverStyle(hoverColor: theme.hover),
          builder: (_, onHover) {
            List<Widget> children = [
              SelectOptionTag(option: option, isSelected: isSelected),
              const Spacer(),
            ];

            if (isSelected) {
              children.add(svgWidget("grid/checkmark"));
            }

            if (onHover) {
              children.add(FlowyIconButton(
                width: 30,
                onPressed: () => _showEditPannel(context),
                iconPadding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                icon: svgWidget("editor/details", color: theme.iconColor),
              ));
            }

            return Padding(
              padding: const EdgeInsets.all(3.0),
              child: Row(children: children),
            );
          },
        ),
      ),
    );
  }

  void _showEditPannel(BuildContext context) {
    final pannel = EditSelectOptionPannel(
      option: option,
      onDeleted: () {
        context.read<SelectOptionEditorBloc>().add(SelectOptionEditorEvent.deleteOption(option));
      },
      onUpdated: (updatedOption) {
        context.read<SelectOptionEditorBloc>().add(SelectOptionEditorEvent.updateOption(updatedOption));
      },
      key: ValueKey(option.id), // Use ValueKey to refresh the UI, otherwise, it will remain the old value.
    );
    final overlayIdentifier = (EditSelectOptionPannel).toString();

    FlowyOverlay.of(context).remove(overlayIdentifier);
    FlowyOverlay.of(context).insertWithAnchor(
      widget: OverlayContainer(
        child: pannel,
        constraints: BoxConstraints.loose(const Size(200, 300)),
      ),
      identifier: overlayIdentifier,
      anchorContext: context,
      anchorDirection: AnchorDirection.rightWithCenterAligned,
      anchorOffset: Offset(2 * overlayContainerPadding.left, 0),
    );
  }
}