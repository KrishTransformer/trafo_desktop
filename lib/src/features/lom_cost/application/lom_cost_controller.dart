import 'package:flutter/foundation.dart';

import '../../../core/models/entity_list_query.dart';
import '../../../core/network/api_exception.dart';
import '../../files/domain/repositories/lom_material_repository.dart';
import '../domain/models/lom_cost_defaults.dart';
import '../domain/models/lom_material_draft.dart';
import '../domain/repositories/lom_material_admin_repository.dart';
import 'lom_cost_state.dart';

class LomCostController extends ChangeNotifier {
  LomCostController({
    required LomMaterialRepository materialRepository,
    required LomMaterialAdminRepository adminRepository,
  }) : _materialRepository = materialRepository,
       _adminRepository = adminRepository;

  final LomMaterialRepository _materialRepository;
  final LomMaterialAdminRepository _adminRepository;

  LomCostState _state = const LomCostState.initial();

  LomCostState get state => _state;

  Future<void> initialize({bool forceRefresh = false}) async {
    if (_state.isInitialized && !forceRefresh) {
      return;
    }

    await refresh();
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }
    _setState(_state.copyWith(errorMessage: ''));
  }

  Future<void> refresh() async {
    _setState(
      _state.copyWith(isInitialized: true, isLoading: true, errorMessage: ''),
    );

    try {
      final response = await _materialRepository.fetchMaterials(
        const EntityListQuery(
          offset: 0,
          size: 100,
          sortAttribute: 'createdAt',
          sortOrder: 'ASC',
        ),
      );

      _setState(_state.copyWith(isLoading: false, materials: response.data));
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isLoading: false,
          materials: const [],
          errorMessage: exception.message,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          materials: const [],
          errorMessage: 'Unable to load LOM material rates.',
        ),
      );
    }
  }

  Future<bool> addMaterial({
    required String materialName,
    required String materialRate,
  }) async {
    final normalizedName = materialName.trim();
    final normalizedRate = num.tryParse(materialRate.trim());
    if (normalizedName.isEmpty || normalizedRate == null) {
      _setState(
        _state.copyWith(
          errorMessage: 'Please fill all fields before adding a material.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _adminRepository.createMaterial(
        LomMaterialDraft(
          materialName: normalizedName,
          materialRate: normalizedRate,
        ),
      );
      _setState(_state.copyWith(isSaving: false));
      await refresh();
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isSaving: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'Unable to add the material rate.',
        ),
      );
      return false;
    }
  }

  Future<bool> updateMaterial({
    required String entityId,
    required String materialName,
    required String materialRate,
  }) async {
    final normalizedName = materialName.trim();
    final normalizedRate = num.tryParse(materialRate.trim());
    if (entityId.isEmpty || normalizedName.isEmpty || normalizedRate == null) {
      _setState(
        _state.copyWith(
          errorMessage: 'Please provide a valid material name and rate.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _adminRepository.updateMaterial(
        entityId: entityId,
        draft: LomMaterialDraft(
          materialName: normalizedName,
          materialRate: normalizedRate,
        ),
      );
      _setState(_state.copyWith(isSaving: false));
      await refresh();
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isSaving: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'Unable to update the material rate.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteMaterial(String entityId) async {
    if (entityId.isEmpty) {
      return false;
    }

    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _adminRepository.deleteMaterial(entityId);
      _setState(_state.copyWith(isSaving: false));
      await refresh();
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isSaving: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'Unable to delete the material rate.',
        ),
      );
      return false;
    }
  }

  Future<bool> resetToDefaults() async {
    _setState(_state.copyWith(isApplyingDefaults: true, errorMessage: ''));

    try {
      final existingResponse = await _materialRepository.fetchMaterials(
        const EntityListQuery(
          offset: 0,
          size: 1000,
          sortAttribute: 'createdAt',
          sortOrder: 'ASC',
        ),
      );

      for (final material in existingResponse.data) {
        final id = material.id;
        if (id.isNotEmpty) {
          await _adminRepository.deleteMaterial(id);
        }
      }

      for (final draft in kLomCostDefaults) {
        await _adminRepository.createMaterial(draft);
      }

      _setState(_state.copyWith(isApplyingDefaults: false));
      await refresh();
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isApplyingDefaults: false,
          errorMessage: exception.message,
        ),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isApplyingDefaults: false,
          errorMessage: 'Unable to reset the default material rates.',
        ),
      );
      return false;
    }
  }

  void _setState(LomCostState value) {
    if (_state == value) {
      return;
    }
    _state = value;
    notifyListeners();
  }
}
