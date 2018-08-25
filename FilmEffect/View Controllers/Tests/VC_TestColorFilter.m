//
//  VC_TestColorFilter.m
//  FilmEffect
//
//  Created by Jun Hyeok Jung on 8/23/18.
//  Copyright © 2018 Jun Hyeok Jung. All rights reserved.
//

#import "VC_TestColorFilter.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface VC_TestColorFilter() <UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    UIImage *loadedImage;
    UIImage *editedImage;
}

@property (weak, nonatomic) IBOutlet UIImageView *mainImageV;

@property (weak, nonatomic) IBOutlet UISlider *sliderRed;
@property (weak, nonatomic) IBOutlet UISlider *sliderGreen;
@property (weak, nonatomic) IBOutlet UISlider *sliderBlue;
@property (weak, nonatomic) IBOutlet UISlider *sliderNoise;

@property (weak, nonatomic) IBOutlet UIButton *btnRed;
@property (weak, nonatomic) IBOutlet UIButton *btnGreen;
@property (weak, nonatomic) IBOutlet UIButton *btnBlue;

@end

@implementation VC_TestColorFilter

#pragma mark - 이펙트 관련 함수들
- (CGContextRef)CGGenerateRGBA8ContextFromImage:(CGImageRef)imageRef CF_RETURNS_RETAINED {
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB(); // image colorspace info
    NSAssert(colorSpaceRef, @"Cannot create RGB color space!");
    
    size_t img_w = CGImageGetWidth(imageRef);  // image width
    size_t img_h = CGImageGetHeight(imageRef); // image height
    
    size_t img_bpc = CGImageGetBitsPerComponent(imageRef); // bits per component
    size_t img_bit = CGImageGetBitsPerPixel(imageRef); // bits per pixel (color depth)
    size_t img_bpr = CGImageGetBytesPerRow(imageRef); // bytes per row
    
//    NSLog(@"==== Image information ====");
//    NSLog(@"[Size] %ld px x %ld px", img_w, img_h);
//    NSLog(@"[Color depth] %ld bit", img_bit);
//    NSLog(@"[Each color depth] %ld bit", img_bpc);
//    NSLog(@"===========================");
    
    unsigned int *imgBitmapData = (unsigned int *)calloc(img_bpr * img_h, sizeof(unsigned int));
    NSAssert(imgBitmapData, @"Cannot allocate image data to memory!");
    
    CGContextRef context = CGBitmapContextCreate(imgBitmapData, // image data
                                                 img_w, // image width
                                                 img_h, // image height
                                                 img_bpc, // image bits per component
                                                 img_bpr, // image bytes per row
                                                 colorSpaceRef, // image color space info
                                                 kCGImageAlphaPremultipliedLast // image bitmap sequence to RGBA
                                                 );
    NSAssert(context, @"Cannot create bitmap context!");
    
    CGRect rect = CGRectMake(0.0f, 0.0f, img_w, img_h);
    CGContextDrawImage(context, rect, imageRef);
    
    CGColorSpaceRelease(colorSpaceRef);
    
    return context;
}

- (void)applyColorFilter {
    CGImageRef imgRef = [loadedImage CGImage];
    CGContextRef imgContextRef = [self CGGenerateRGBA8ContextFromImage:imgRef];
    
    size_t img_w = CGImageGetWidth(imgRef);  // image width
    size_t img_h = CGImageGetHeight(imgRef); // image height
    size_t img_bpr = CGImageGetBytesPerRow(imgRef); // bytes per row
    
   unsigned char *imgBitmapData = (unsigned char *)CGBitmapContextGetData(imgContextRef);
    NSAssert(imgBitmapData, @"Cannot get image bitmap data to memory!");
    
    unsigned char *editedImageBitmapData = (unsigned char *)calloc(img_bpr * img_h, sizeof(unsigned char));
    NSAssert(editedImageBitmapData, @"Cannot allocate edited image bitmap data to memory!");
    
    float rVal = ([self.sliderRed value] - 0.5) / 0.5 * 255;
    float gVal = ([self.sliderGreen value] - 0.5) / 0.5 * 255;
    float bVal = ([self.sliderBlue value] - 0.5) / 0.5 * 255;
    
//    NSLog(@"[FILTER] - R: %.1f , G: %.1f , B: %.1f", rVal, gVal, bVal);
    
    for(int y = 0; y < img_h; y++) {
        for(int x = 0; x < img_w; x++) {
            int idx = (x + (y * (int)img_w)) * 4;
            
            int finalR = imgBitmapData[idx] + rVal;
            int finalG = imgBitmapData[idx + 1] + gVal;
            int finalB = imgBitmapData[idx + 2] + bVal;
            
            if(0 >= finalR) {
                finalR = 0;
            }
            if(255 <= finalR) {
                finalR = 255;
            }
            
            if(0 >= finalG) {
                finalG = 0;
            }
            if(255 <= finalG) {
                finalG = 255;
            }
            
            if(0 >= finalB) {
                finalB = 0;
            }
            if(255 <= finalB) {
                finalB = 255;
            }
            
            editedImageBitmapData[idx] = finalR;     // R
            editedImageBitmapData[idx + 1] = finalG; // G
            editedImageBitmapData[idx + 2] = finalB; // B
            editedImageBitmapData[idx + 3] = imgBitmapData[idx + 3]; // A
        }
    }
    
    editedImage = NULL;
    editedImage = [self createImageWithRGBA8Bitmap:editedImageBitmapData withCGSize:CGSizeMake(img_w, img_h)];
    
    free(imgBitmapData);
    free(editedImageBitmapData);
    CGContextRelease(imgContextRef);
}

- (void)applyNoise {
    CGFloat noiseLevel = [self.sliderNoise value];

    CGImageRef imgRef = [editedImage CGImage];
    CGImageRef noiseRef = [self CGGenerateNoiseImage:[editedImage size] withFactor:noiseLevel];
    
    CGContextRef imgContextRef = [self CGGenerateRGBA8ContextFromImage:imgRef];
    
    CGRect rect = CGRectMake(0.0f, 0.0f, [editedImage size].width, [editedImage size].height);
    
    CGContextSetBlendMode(imgContextRef, kCGBlendModeOverlay);
    CGContextDrawImage(imgContextRef, rect, noiseRef);
    CGContextSetBlendMode(imgContextRef, kCGBlendModeNormal);
    
    unsigned char *imgBitmapData = (unsigned char *)CGBitmapContextGetData(imgContextRef);
    NSAssert(imgBitmapData, @"Cannot get image bitmap data to memory!");
    
    editedImage = [self createImageWithRGBA8Bitmap:imgBitmapData withCGSize:[editedImage size]];
    
    free(imgBitmapData);
    CGContextRelease(imgContextRef);
    CGImageRelease(noiseRef);
}

- (CGImageRef)CGGenerateNoiseImage:(CGSize)size withFactor:(CGFloat)factor CF_RETURNS_RETAINED {
    unsigned char *noise = (unsigned char *)calloc(size.width * size.height, sizeof(unsigned char));
    NSAssert(noise, @"Cannot allocate memory for noise!");
    
    for(int i = 0; i < (size.width * size.height); i++) { // generate noise
        noise[i] = (unsigned char)((arc4random() % 128) * factor) + 128;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceGray();
    NSAssert(colorSpace, @"Cannot create color space!");
    
    CGContextRef context = CGBitmapContextCreate(noise,       //data
                                                 size.width,  // width
                                                 size.height, // height
                                                 8,           // bits per component
                                                 fabs(size.width), // bytes per row
                                                 colorSpace,       // colorspace
                                                 kCGImageAlphaNone // image info (color sequence)
                                                 );
    NSAssert(context, @"Cannot create bitmap context!");

    CGImageRef image = CGBitmapContextCreateImage(context);
    
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(noise);
    
    return image;
}

- (UIImage *)createImageWithRGBA8Bitmap:(unsigned char *)data withCGSize:(CGSize)size {
    size_t img_w = size.width;
    size_t img_h = size.height;
    
    size_t img_bpr = img_w * 4;
    size_t img_bpc = 8;
    size_t img_bpp = 32;
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(nil, data, img_bpr * img_h, nil);
    NSAssert(provider, @"Cannot create provider data to memory!");
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    NSAssert(colorSpaceRef, @"Cannot create RGB color space!");
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef imgRef = CGImageCreate(img_w,             // image width
                                      img_h,             // image height
                                      img_bpc,           // image bits per component
                                      img_bpp,           // image bits per pixel
                                      img_bpr,           // image bits per row
                                      colorSpaceRef,     // color space reference
                                      bitmapInfo,        // bitmap information (byte order)
                                      provider,          // data provider
                                      nil,               // decode
                                      YES,               // interpolation Y/N
                                      renderingIntent);  // rendering intent
    NSAssert(imgRef, @"Cannot create image referenece!");
    
    unsigned char *pixels = (unsigned char *)calloc(img_bpr * img_h, sizeof(unsigned char));
    NSAssert(imgRef, @"Cannot allocate memory for pixel data!");
    
    CGContextRef context = CGBitmapContextCreate(pixels, // image data
                                                 img_w, // image width
                                                 img_h, // image height
                                                 img_bpc, // image bits per component
                                                 img_bpr, // image bytes per row
                                                 colorSpaceRef, // image color space info
                                                 kCGImageAlphaPremultipliedLast // image bitmap sequence to RGBA
                                                 );
    NSAssert(context, @"Cannot create bitmap context!");
    
    UIImage *resultImg = nil;
    
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, img_w, img_h), imgRef);
    CGImageRef generatedImgRef = CGBitmapContextCreateImage(context);
    
    resultImg = [UIImage imageWithCGImage:generatedImgRef];
    
    CGImageRelease(generatedImgRef);
    free(pixels);
    CGContextRelease(context);
    CGImageRelease(imgRef);
    CGColorSpaceRelease(colorSpaceRef);
    CGDataProviderRelease(provider);
    
    return resultImg;
}

#pragma mark - 뷰 컨트롤러 함수들
- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - 버튼 액션 (색상)
- (IBAction)btnRedPressed:(UIButton *)sender {
//    NSLog(@"Resetting red slider value to 0.5");
    [self.sliderRed setValue:0.5f animated:YES];
    [self updateFilteredImageView];
}

- (IBAction)btnGreenPressed:(UIButton *)sender {
//    NSLog(@"Resetting green slider value to 0.5");
    [self.sliderGreen setValue:0.5f animated:YES];
    [self updateFilteredImageView];
}

- (IBAction)btnBluePressed:(UIButton *)sender {
//    NSLog(@"Resetting blue slider value to 0.5");
    [self.sliderBlue setValue:0.5f animated:YES];
    [self updateFilteredImageView];
}

#pragma mark - 버튼 액션 (이미지 관련)
- (IBAction)btnLoadImagePressed:(UIButton *)sender {
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    [imagePicker setDelegate:self];
    [imagePicker setMediaTypes:[[NSArray alloc] initWithObjects:(NSString *)kUTTypeImage, nil]];
    [imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
    [self.parentViewController presentViewController:imagePicker animated:YES completion:^{}];
    
    //TODO: 이미지 불러오면, 썸네일 만들고(이미지 뷰 크기 만큼) for speedy process
    // 저장할 때 이제 해당 값을 적용해서 갤러리에 저장 (스피너 돌려야겠제?)
}

- (IBAction)btnSaveImagePressed:(UIButton *)sender {
    if(loadedImage) {
        if(editedImage) {
            UIImageWriteToSavedPhotosAlbum(editedImage, nil, nil, nil);
            [self showAlertWithTitle:@"성공!"
                            contents:@"이미지가 성공적으로 갤러리에 저장되었습니다."
                           andAction:[UIAlertAction actionWithTitle:@"확인" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
        } else {
            [self showAlertWithTitle:@"Warning!"
                            contents:@"The image that you are trying to save is same with original!"
                           andAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
        }
    } else {
        [self showAlertWithTitle:@"Warning!"
                        contents:@"There have no loaded images!"
                       andAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
    }
}

#pragma mark - 슬라이더 액션
-(IBAction)sliderRedValueChanged:(UISlider *)sender {
//    NSLog(@"Red slider value has changed! - %.2f", sender.value);
    [self updateFilteredImageView];
}

-(IBAction)sliderGreenValueChanged:(UISlider *)sender {
//    NSLog(@"Green slider value has changed! - %.2f", sender.value);
    [self updateFilteredImageView];
}

-(IBAction)sliderBlueValueChanged:(UISlider *)sender {
//    NSLog(@"Blue slider value has changed! - %.2f", sender.value);
    [self updateFilteredImageView];
}

-(IBAction)sliderNoiseLevelValueChanged:(UISlider *)sender {
    //    NSLog(@"Noise level slider value has changed! - %.2f", sender.value);
    [self updateFilteredImageView];
}

#pragma mark - 이미지 피커 Delegate
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{}];
    loadedImage = editedImage = nil;
    [self updateFilteredImageView];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{}];
    loadedImage = [info objectForKey:UIImagePickerControllerOriginalImage];
    editedImage = loadedImage;
    [self updateFilteredImageView];
}

#pragma mark - 기타
- (void)updateFilteredImageView {
    if(loadedImage) {
        [self applyColorFilter];
        [self applyNoise];
        [self.mainImageV setImage:editedImage];
    } else {
        [self.mainImageV setImage:nil];
    }
}

- (void)showAlertWithTitle:(NSString *)title contents:(NSString *)contents andAction:(UIAlertAction *)action {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:contents
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:^{}];
}

@end
