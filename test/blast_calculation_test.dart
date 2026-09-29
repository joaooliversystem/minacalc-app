import 'package:flutter_test/flutter_test.dart';
import 'package:minacalc_pro/services/blast_calculation.dart';
import 'package:minacalc_pro/services/formula_engine.dart';

void main() {
  BlastCalculationResult calculate(String category) => BlastCalculation.calculate(
        formulaEngine: FormulaEngine(const []),
        explosiveCategory: category,
        holeDiameterMm: 76.2,
        explosiveDiameterMm: 60,
        explosiveDensityGcm3: 1.15,
        benchHeightM: 10,
        holeDepthM: 10.5,
        subdrillingM: 0,
        depthMode: 'manual',
        stemmingHeightM: 3,
        holes: 150,
        burdenM: 2,
        spacingM: 4,
        rockDensityTm3: 0,
      );

  test('PF-2026-0002 bombeado usa diametro do furo', () {
    final r = calculate('emulsion_pumped');
    expect(r.calculationDiameterMm, 76.2);
    expect(r.kgPerMeter, 5.24);
    expect(r.chargedLengthM, 7.5);
    expect(r.chargePerHoleKg, 39.33);
    expect(r.volumePerHoleM3, 80);
    expect(r.powderFactorKgM3, 0.492);
    expect(r.volumeM3, 12000);
    expect(r.estimatedChargeKg, closeTo(5899.98, 0.02));
  });

  test('PF-2026-0002 encartuchado usa diametro do cartucho', () {
    final r = calculate('cartridge');
    expect(r.calculationDiameterMm, 60);
    expect(r.kgPerMeter, 3.25);
    expect(r.chargedLengthM, 7.5);
    expect(r.chargePerHoleKg, 24.39);
    expect(r.volumePerHoleM3, 80);
    expect(r.powderFactorKgM3, 0.305);
    expect(r.volumeM3, 12000);
    expect(r.estimatedChargeKg, closeTo(3657.99, 0.02));
  });
}
