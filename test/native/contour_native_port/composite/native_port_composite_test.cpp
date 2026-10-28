#include "contour_native_port.cpp"
#include <iostream>

int main() {
  using namespace contour_native_port;
  std::array<uint8_t, 8 * 8 * 4> rgba{};
  for (size_t i = 0; i < rgba.size(); i += 4) {
    rgba[i] = rgba[i + 3] = 255;
  }
  std::array<double, 2 * 25> descriptors{};
  for (size_t tile = 0; tile < 2; tile++) {
    auto *values = descriptors.data() + tile * 25;
    values[2] = values[3] = 8;
    values[4] = values[5] = 1;
    values[6] = 2;
    values[7] = tile == 0 ? 0xffffffff : 0xff123456;
    values[8] = 1;
    values[9] = 0.75;
    values[10] = 1;
    values[11] = 2;
    values[12] = 0x44000000;
  }
  std::array<Dart_CObject, 9> fields{};
  std::array<Dart_CObject *, 9> pointers{};
  for (size_t i = 0; i < fields.size(); i++) pointers[i] = &fields[i];
  fields[3].type = Dart_CObject_kTypedData;
  fields[3].value.as_typed_data = {Dart_TypedData_kUint8, intptr_t(rgba.size()), rgba.data()};
  fields[4] = fields[5] = integer(8);
  fields[6] = integer(8 * 4);
  fields[8] = integer(1);
  fields[7].type = Dart_CObject_kTypedData;
  alignas(double) std::array<uint8_t, sizeof(descriptors) + alignof(double) - 1> bytes{};
  contour_cpu::Output reference;
  for (size_t offset = 0; offset < alignof(double); offset++) {
    std::memcpy(bytes.data() + offset, descriptors.data(), sizeof(descriptors));
    fields[7].value.as_typed_data = {
        Dart_TypedData_kFloat64, intptr_t(descriptors.size()), bytes.data() + offset};
    auto job = std::make_shared<Job>(std::make_shared<Context>(1), 1, rgba.size(), 64 * 1024 * 1024, true);
    const auto status = executeComposite(job, pointers.data());
    auto &output = job->compositeOutput;
    if (status != 0 || output.placements.size() != 2 || output.rgba.empty() ||
        (offset != 0 && (output.width != reference.width || output.height != reference.height ||
                         output.rgba != reference.rgba))) {
      std::cerr << "Composite changed at byte alignment " << offset << ", status " << status << '\n';
      return 1;
    }
    if (offset == 0) reference = std::move(output);
  }
}
