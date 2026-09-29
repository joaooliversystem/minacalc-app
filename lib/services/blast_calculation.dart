import 'dart:math' as math;

import 'formula_engine.dart';

class BlastCalculationResult {
  final String calculationVersion;
  final String diameterSource;
  final double calculationDiameterMm;
  final double effectiveHoleDepthM;
  final double stemmingHeightM;
  final double chargedLengthM;
  final double kgPerMeter;
  final double chargePerHoleKg;
  final double volumePerHoleM3;
  final double powderFactorKgM3;
  final double volumeM3;
  final double drillingM;
  final double estimatedChargeKg;
  final double? tonnageT;
  final List<Map<String, dynamic>> formulaSnapshot;

  const BlastCalculationResult({
    required this.calculationVersion,
    required this.diameterSource,
    required this.calculationDiameterMm,
    required this.effectiveHoleDepthM,
    required this.stemmingHeightM,
    required this.chargedLengthM,
    required this.kgPerMeter,
    required this.chargePerHoleKg,
    required this.volumePerHoleM3,
    required this.powderFactorKgM3,
    required this.volumeM3,
    required this.drillingM,
    required this.estimatedChargeKg,
    required this.tonnageT,
    required this.formulaSnapshot,
  });

  Map<String, dynamic> toSummary({double? rockDensity}) => {
        'calculation_version': calculationVersion,
        'formula_policy': 'published_only',
        'formula_snapshot': formulaSnapshot,
        'effective_hole_depth_m': effectiveHoleDepthM,
        'stemming_height_m': stemmingHeightM,
        'charged_length_m': chargedLengthM,
        'calculation_diameter_mm': calculationDiameterMm,
        'calculation_diameter_source': diameterSource,
        'kg_per_meter': kgPerMeter,
        'charge_per_hole_kg': chargePerHoleKg,
        'volume_per_hole_m3': volumePerHoleM3,
        'powder_factor_kg_m3': powderFactorKgM3,
        'volume_m3': volumeM3,
        'drilling_m': drillingM,
        'estimated_charge_kg': estimatedChargeKg,
        'estimated_charge_per_hole_kg': chargePerHoleKg,
        'rock_density_t_m3': rockDensity != null && rockDensity > 0 ? rockDensity : null,
        'tonnage_t': tonnageT,
      };
}

class BlastCalculation {
  static const List<String> formulaKeys = [
    'charged_length_m',
    'kg_per_meter',
    'volume_per_hole_m3',
    'charge_per_hole_kg',
    'powder_factor_kg_m3',
    'volume_m3',
    'drilling_m',
    'estimated_charge_kg',
    'estimated_charge_per_hole_kg',
    'tonnage_t',
  ];

  static double _round(double value, int precision) {
    final factor = math.pow(10, precision).toDouble();
    return (value * factor).roundToDouble() / factor;
  }

  static BlastCalculationResult calculate({
    required FormulaEngine formulaEngine,
    required String explosiveCategory,
    required double holeDiameterMm,
    required double explosiveDiameterMm,
    required double explosiveDensityGcm3,
    required double benchHeightM,
    required double holeDepthM,
    required double subdrillingM,
    required String depthMode,
    required double stemmingHeightM,
    required int holes,
    required double burdenM,
    required double spacingM,
    required double rockDensityTm3,
  }) {
    final effectiveDepth = math.max(0.0, depthMode == 'bench_plus_subdrilling' ? benchHeightM + subdrillingM : holeDepthM);
    final stemming = math.max(0.0, stemmingHeightM);

    late final double calculationDiameter;
    late final String diameterSource;
    if (explosiveCategory == 'cartridge') {
      calculationDiameter = math.max(0.0, explosiveDiameterMm);
      diameterSource = 'cartridge';
    } else if (explosiveCategory == 'emulsion_pumped' || explosiveCategory == 'anfo') {
      calculationDiameter = math.max(0.0, holeDiameterMm);
      diameterSource = 'hole';
    } else if (explosiveDiameterMm > 0) {
      calculationDiameter = explosiveDiameterMm;
      diameterSource = 'configured_explosive';
    } else {
      calculationDiameter = math.max(0.0, holeDiameterMm);
      diameterSource = 'hole';
    }

    final context = <String, double>{
      'burden': math.max(0.0, burdenM),
      'spacing': math.max(0.0, spacingM),
      'bench_height': math.max(0.0, benchHeightM),
      'holes': math.max(0, holes).toDouble(),
      'effective_hole_depth': effectiveDepth,
      'stemming_height': stemming,
      'calculation_diameter_mm': calculationDiameter,
      'explosive_density': math.max(0.0, explosiveDensityGcm3),
      'rock_density': math.max(0.0, rockDensityTm3),
    };

    final fallbackCharged = math.max(0.0, effectiveDepth - stemming);
    final chargedRaw = math.max(0.0, formulaEngine.evaluate('charged_length_m', context, fallback: fallbackCharged) ?? fallbackCharged);
    context['charged_length_m'] = chargedRaw;
    final charged = _round(chargedRaw, 2);

    final dM = calculationDiameter / 1000;
    final densityKgM3 = math.max(0.0, explosiveDensityGcm3) * 1000;
    final fallbackKgM = dM > 0 && densityKgM3 > 0 ? math.pi * math.pow(dM, 2) / 4 * densityKgM3 : 0.0;
    final kgMRaw = math.max(0.0, formulaEngine.evaluate('kg_per_meter', context, fallback: fallbackKgM) ?? fallbackKgM);
    context['kg_per_meter'] = kgMRaw;
    final kgM = _round(kgMRaw, 2);

    final fallbackVolumeHole = math.max(0.0, burdenM) * math.max(0.0, spacingM) * math.max(0.0, benchHeightM);
    final volumeHoleRaw = math.max(0.0, formulaEngine.evaluate('volume_per_hole_m3', context, fallback: fallbackVolumeHole) ?? fallbackVolumeHole);
    context['volume_per_hole_m3'] = volumeHoleRaw;
    final volumeHole = _round(volumeHoleRaw, 2);

    final fallbackChargeHole = kgMRaw * chargedRaw;
    final chargeHoleRaw = math.max(0.0, formulaEngine.evaluate('charge_per_hole_kg', context, fallback: fallbackChargeHole) ?? fallbackChargeHole);
    context['charge_per_hole_kg'] = chargeHoleRaw;
    final chargeHole = _round(chargeHoleRaw, 2);

    final fallbackPowder = volumeHoleRaw > 0 ? chargeHoleRaw / volumeHoleRaw : 0.0;
    final powderRaw = math.max(0.0, formulaEngine.evaluate('powder_factor_kg_m3', context, fallback: fallbackPowder) ?? fallbackPowder);
    context['powder_factor_kg_m3'] = powderRaw;
    final powder = _round(powderRaw, 3);

    final fallbackVolume = volumeHoleRaw * math.max(0, holes);
    final volumeRaw = math.max(0.0, formulaEngine.evaluate('volume_m3', context, fallback: fallbackVolume) ?? fallbackVolume);
    context['volume_m3'] = volumeRaw;
    final volume = _round(volumeRaw, 2);

    final fallbackDrilling = effectiveDepth * math.max(0, holes);
    final drillingRaw = math.max(0.0, formulaEngine.evaluate('drilling_m', context, fallback: fallbackDrilling) ?? fallbackDrilling);
    context['drilling_m'] = drillingRaw;
    final drilling = _round(drillingRaw, 2);

    final fallbackCharge = chargeHoleRaw * math.max(0, holes);
    final totalChargeRaw = math.max(0.0, formulaEngine.evaluate('estimated_charge_kg', context, fallback: fallbackCharge) ?? fallbackCharge);
    context['estimated_charge_kg'] = totalChargeRaw;
    context['estimated_charge_per_hole_kg'] = chargeHoleRaw;
    final totalCharge = _round(totalChargeRaw, 2);

    final fallbackTonnage = rockDensityTm3 > 0 ? volumeRaw * rockDensityTm3 : null;
    final tonnage = rockDensityTm3 > 0
        ? _round(math.max(0.0, formulaEngine.evaluate('tonnage_t', context, fallback: fallbackTonnage) ?? fallbackTonnage!), 2)
        : null;

    return BlastCalculationResult(
      calculationVersion: 'formula-engine-2.2',
      diameterSource: diameterSource,
      calculationDiameterMm: _round(calculationDiameter, 2),
      effectiveHoleDepthM: _round(effectiveDepth, 2),
      stemmingHeightM: _round(stemming, 2),
      chargedLengthM: charged,
      kgPerMeter: kgM,
      chargePerHoleKg: chargeHole,
      volumePerHoleM3: volumeHole,
      powderFactorKgM3: powder,
      volumeM3: volume,
      drillingM: drilling,
      estimatedChargeKg: totalCharge,
      tonnageT: tonnage,
      formulaSnapshot: formulaEngine.snapshotFor(formulaKeys),
    );
  }
}
