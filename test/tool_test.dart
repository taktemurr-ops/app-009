import 'package:flutter_test/flutter_test.dart';
import 'package:uyg_butce_ve_harcama_takibi/uyg_butce_ve_harcama_takibi.dart';

void main() {
  test('33 dilde ad ve açıklama, doğru kimlik', () {
    expect(butceVeHarcamaTakibiTool.id, butceVeHarcamaTakibiId);
    expect(butceVeHarcamaTakibiTool.title.length, 33);
    expect(butceVeHarcamaTakibiTool.tagline.length, 33);
  });
}
