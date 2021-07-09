OS_NAME = uefios
export PATH := $(abspath tools/x86_64-elf-cross/bin):$(PATH)
BUILD_DIR = $(abspath build)
SOURCE_DIR = $(abspath src)
OVMF_BINARIES_DIR = ovmf-bins
GNU_EFI_DIR = gnu-efi

EFI_TARGET = loader.efi
ELF_TARGET = kernel.elf

EMU = qemu-system-x86_64
DBG = gdb

EMU_BASE_FLAGS = -drive file=$(BUILD_DIR)/$(OS_NAME).img,format=raw \
				-m 512M \
				-cpu qemu64 \
				-machine q35 \
				-drive if=pflash,format=raw,unit=0,file="$(OVMF_BINARIES_DIR)/OVMF_CODE-pure-efi.fd",readonly=on \
				-drive if=pflash,format=raw,unit=1,file="$(OVMF_BINARIES_DIR)/OVMF_VARS-pure-efi.fd" \
				-net none

EMU_DBG_FLAGS = -s -d guest_errors,cpu_reset,int -no-reboot -no-shutdown

DBG_FLAGS = -ex "target remote localhost:1234" \
			-ex "symbol-file $(BUILD_DIR)/kernel/$(ELF_TARGET)" \
			-ex "set disassemble-next-line on" \
			-ex "set step-mode on"



partial: build update_img	

all: build make_img

build: build_bootloader build_kernel

build_bootloader:
	@mkdir -p $(BUILD_DIR)
	$(MAKE) -C $(GNU_EFI_DIR) all
	$(MAKE) -C $(SOURCE_DIR)/bootloader EFI_TARGET=$(EFI_TARGET) BUILD_DIR=$(BUILD_DIR)/bootloader all

build_kernel:
	@mkdir -p $(BUILD_DIR)
	$(MAKE) -C $(SOURCE_DIR)/kernel ELF_TARGET=$(ELF_TARGET) BUILD_DIR=$(BUILD_DIR)/kernel all

make_img: init_img update_img

update_img:
	mformat -i $(BUILD_DIR)/$(OS_NAME).img -F ::
	mmd -i $(BUILD_DIR)/$(OS_NAME).img ::/EFI
	mmd -i $(BUILD_DIR)/$(OS_NAME).img ::/EFI/BOOT
	mcopy -i $(BUILD_DIR)/$(OS_NAME).img $(BUILD_DIR)/bootloader/$(EFI_TARGET) ::/EFI/BOOT

init_img:
	dd if=/dev/zero of=$(BUILD_DIR)/$(OS_NAME).img bs=512 count=93750

run:
	$(EMU) $(EMU_BASE_FLAGS)

debug:
	$(EMU) $(EMU_BASE_FLAGS) $(EMU_DBG_FLAGS) &
	$(DBG) $(DBG_FLAGS)

clean:
	$(MAKE) -C gnu-efi clean
	rm -rf $(SOURCE_DIR)/**/*.o
	rm -rf $(BUILD_DIR)