
import { ColorsInterface } from './TokenInterfaces';

export class LightThemeColors implements ColorsInterface {
  readonly PRIMARY: ResourceColor;
  readonly PRIMARY_DARK: ResourceColor;
  readonly PRIMARY_LIGHT: ResourceColor;
  readonly PRIMARY_LIGHTEST: ResourceColor;

  readonly SECONDARY: ResourceColor;
  readonly SECONDARY_DARK: ResourceColor;
  readonly SECONDARY_LIGHT: ResourceColor;
  readonly SECONDARY_LIGHTEST: ResourceColor;

  readonly SUCCESS: ResourceColor;
  readonly SUCCESS_DARK: ResourceColor;
  readonly SUCCESS_LIGHT: ResourceColor;
  readonly SUCCESS_LIGHTEST: ResourceColor;

  readonly ERROR: ResourceColor;
  readonly ERROR_DARK: ResourceColor;
  readonly ERROR_LIGHT: ResourceColor;
  readonly ERROR_LIGHTEST: ResourceColor;

  readonly WARNING: ResourceColor;
  readonly WARNING_DARK: ResourceColor;
  readonly WARNING_LIGHT: ResourceColor;
  readonly WARNING_LIGHTEST: ResourceColor;

  readonly INFO: ResourceColor;
  readonly INFO_DARK: ResourceColor;
  readonly INFO_LIGHT: ResourceColor;
  readonly INFO_LIGHTEST: ResourceColor;

  readonly WHITE: ResourceColor;
  readonly BLACK: ResourceColor;
  
  readonly GRAY_50: ResourceColor;
  readonly GRAY_100: ResourceColor;
  readonly GRAY_200: ResourceColor;
  readonly GRAY_300: ResourceColor;
  readonly GRAY_400: ResourceColor;
  readonly GRAY_500: ResourceColor;
  readonly GRAY_600: ResourceColor;
  readonly GRAY_700: ResourceColor;
  readonly GRAY_800: ResourceColor;
  readonly GRAY_900: ResourceColor;

  readonly BACKGROUND_PRIMARY: ResourceColor;
  readonly BACKGROUND_SECONDARY: ResourceColor;
  readonly BACKGROUND_TERTIARY: ResourceColor;
  readonly SURFACE_PRIMARY: ResourceColor;
  readonly SURFACE_ELEVATED: ResourceColor;

  readonly TEXT_PRIMARY: ResourceColor;
  readonly TEXT_SECONDARY: ResourceColor;
  readonly TEXT_TERTIARY: ResourceColor;
  readonly TEXT_DISABLED: ResourceColor;

  readonly BORDER_LIGHT: ResourceColor;
  readonly BORDER_MEDIUM: ResourceColor;
  readonly BORDER_DARK: ResourceColor;

  readonly SHADOW_LIGHT: ResourceColor;
  readonly SHADOW_MEDIUM: ResourceColor;
  readonly SHADOW_DARK: ResourceColor;

  readonly STATUS_NEW: ResourceColor;
  readonly STATUS_LEARNING: ResourceColor;
  readonly STATUS_REVIEW: ResourceColor;
  readonly STATUS_RELEARNING: ResourceColor;

  readonly PURPLE: ResourceColor;
  readonly INDIGO: ResourceColor;
  readonly BROWN: ResourceColor;

  constructor(overrides?: Partial<ColorsInterface>) {
    this.PRIMARY = overrides?.PRIMARY ?? '#007DFF';
    this.PRIMARY_DARK = overrides?.PRIMARY_DARK ?? '#005BB5';
    this.PRIMARY_LIGHT = overrides?.PRIMARY_LIGHT ?? '#4DA3FF';
    this.PRIMARY_LIGHTEST = overrides?.PRIMARY_LIGHTEST ?? '#E6F2FF';

    this.SECONDARY = overrides?.SECONDARY ?? '#F44336';
    this.SECONDARY_DARK = overrides?.SECONDARY_DARK ?? '#D32F2F';
    this.SECONDARY_LIGHT = overrides?.SECONDARY_LIGHT ?? '#E57373';
    this.SECONDARY_LIGHTEST = overrides?.SECONDARY_LIGHTEST ?? '#FFEBEE';

    this.SUCCESS = overrides?.SUCCESS ?? '#4CAF50';
    this.SUCCESS_DARK = overrides?.SUCCESS_DARK ?? '#388E3C';
    this.SUCCESS_LIGHT = overrides?.SUCCESS_LIGHT ?? '#81C784';
    this.SUCCESS_LIGHTEST = overrides?.SUCCESS_LIGHTEST ?? '#E8F5E9';

    this.ERROR = overrides?.ERROR ?? '#F44336';
    this.ERROR_DARK = overrides?.ERROR_DARK ?? '#D32F2F';
    this.ERROR_LIGHT = overrides?.ERROR_LIGHT ?? '#E57373';
    this.ERROR_LIGHTEST = overrides?.ERROR_LIGHTEST ?? '#FFEBEE';

    this.WARNING = overrides?.WARNING ?? '#FFEB3B';
    this.WARNING_DARK = overrides?.WARNING_DARK ?? '#FBC02D';
    this.WARNING_LIGHT = overrides?.WARNING_LIGHT ?? '#FFF176';
    this.WARNING_LIGHTEST = overrides?.WARNING_LIGHTEST ?? '#FFFDE7';

    this.INFO = overrides?.INFO ?? '#00BCD4';
    this.INFO_DARK = overrides?.INFO_DARK ?? '#0097A7';
    this.INFO_LIGHT = overrides?.INFO_LIGHT ?? '#4DD0E1';
    this.INFO_LIGHTEST = overrides?.INFO_LIGHTEST ?? '#E0F7FA';

    this.WHITE = overrides?.WHITE ?? '#FFFFFF';
    this.BLACK = overrides?.BLACK ?? '#000000';
    
    this.GRAY_50 = overrides?.GRAY_50 ?? '#FAFAFA';
    this.GRAY_100 = overrides?.GRAY_100 ?? '#F5F5F5';
    this.GRAY_200 = overrides?.GRAY_200 ?? '#EEEEEE';
    this.GRAY_300 = overrides?.GRAY_300 ?? '#E0E0E0';
    this.GRAY_400 = overrides?.GRAY_400 ?? '#BDBDBD';
    this.GRAY_500 = overrides?.GRAY_500 ?? '#9E9E9E';
    this.GRAY_600 = overrides?.GRAY_600 ?? '#757575';
    this.GRAY_700 = overrides?.GRAY_700 ?? '#616161';
    this.GRAY_800 = overrides?.GRAY_800 ?? '#424242';
    this.GRAY_900 = overrides?.GRAY_900 ?? '#212121';

    this.BACKGROUND_PRIMARY = overrides?.BACKGROUND_PRIMARY ?? '#FFFFFF';
    this.BACKGROUND_SECONDARY = overrides?.BACKGROUND_SECONDARY ?? '#F5F5F5';
    this.BACKGROUND_TERTIARY = overrides?.BACKGROUND_TERTIARY ?? '#EEEEEE';
    this.SURFACE_PRIMARY = overrides?.SURFACE_PRIMARY ?? '#FFFFFF';
    this.SURFACE_ELEVATED = overrides?.SURFACE_ELEVATED ?? '#FFFFFF';

    this.TEXT_PRIMARY = overrides?.TEXT_PRIMARY ?? '#212121';
    this.TEXT_SECONDARY = overrides?.TEXT_SECONDARY ?? '#757575';
    this.TEXT_TERTIARY = overrides?.TEXT_TERTIARY ?? '#9E9E9E';
    this.TEXT_DISABLED = overrides?.TEXT_DISABLED ?? '#BDBDBD';

    this.BORDER_LIGHT = overrides?.BORDER_LIGHT ?? '#E0E0E0';
    this.BORDER_MEDIUM = overrides?.BORDER_MEDIUM ?? '#BDBDBD';
    this.BORDER_DARK = overrides?.BORDER_DARK ?? '#9E9E9E';

    this.SHADOW_LIGHT = overrides?.SHADOW_LIGHT ?? '#0000000D';
    this.SHADOW_MEDIUM = overrides?.SHADOW_MEDIUM ?? '#00000014';
    this.SHADOW_DARK = overrides?.SHADOW_DARK ?? '#0000001F';

    this.STATUS_NEW = overrides?.STATUS_NEW ?? '#007DFF';
    this.STATUS_LEARNING = overrides?.STATUS_LEARNING ?? '#F44336';
    this.STATUS_REVIEW = overrides?.STATUS_REVIEW ?? '#9C27B0';
    this.STATUS_RELEARNING = overrides?.STATUS_RELEARNING ?? '#E91E63';

    this.PURPLE = overrides?.PURPLE ?? '#9C27B0';
    this.INDIGO = overrides?.INDIGO ?? '#3F51B5';
    this.BROWN = overrides?.BROWN ?? '#795548';
  }
}

export class DarkThemeColors implements ColorsInterface {
  readonly PRIMARY: ResourceColor;
  readonly PRIMARY_DARK: ResourceColor;
  readonly PRIMARY_LIGHT: ResourceColor;
  readonly PRIMARY_LIGHTEST: ResourceColor;

  readonly SECONDARY: ResourceColor;
  readonly SECONDARY_DARK: ResourceColor;
  readonly SECONDARY_LIGHT: ResourceColor;
  readonly SECONDARY_LIGHTEST: ResourceColor;

  readonly SUCCESS: ResourceColor;
  readonly SUCCESS_DARK: ResourceColor;
  readonly SUCCESS_LIGHT: ResourceColor;
  readonly SUCCESS_LIGHTEST: ResourceColor;

  readonly ERROR: ResourceColor;
  readonly ERROR_DARK: ResourceColor;
  readonly ERROR_LIGHT: ResourceColor;
  readonly ERROR_LIGHTEST: ResourceColor;

  readonly WARNING: ResourceColor;
  readonly WARNING_DARK: ResourceColor;
  readonly WARNING_LIGHT: ResourceColor;
  readonly WARNING_LIGHTEST: ResourceColor;

  readonly INFO: ResourceColor;
  readonly INFO_DARK: ResourceColor;
  readonly INFO_LIGHT: ResourceColor;
  readonly INFO_LIGHTEST: ResourceColor;

  readonly WHITE: ResourceColor;
  readonly BLACK: ResourceColor;
  
  readonly GRAY_50: ResourceColor;
  readonly GRAY_100: ResourceColor;
  readonly GRAY_200: ResourceColor;
  readonly GRAY_300: ResourceColor;
  readonly GRAY_400: ResourceColor;
  readonly GRAY_500: ResourceColor;
  readonly GRAY_600: ResourceColor;
  readonly GRAY_700: ResourceColor;
  readonly GRAY_800: ResourceColor;
  readonly GRAY_900: ResourceColor;

  readonly BACKGROUND_PRIMARY: ResourceColor;
  readonly BACKGROUND_SECONDARY: ResourceColor;
  readonly BACKGROUND_TERTIARY: ResourceColor;
  readonly SURFACE_PRIMARY: ResourceColor;
  readonly SURFACE_ELEVATED: ResourceColor;

  readonly TEXT_PRIMARY: ResourceColor;
  readonly TEXT_SECONDARY: ResourceColor;
  readonly TEXT_TERTIARY: ResourceColor;
  readonly TEXT_DISABLED: ResourceColor;

  readonly BORDER_LIGHT: ResourceColor;
  readonly BORDER_MEDIUM: ResourceColor;
  readonly BORDER_DARK: ResourceColor;

  readonly SHADOW_LIGHT: ResourceColor;
  readonly SHADOW_MEDIUM: ResourceColor;
  readonly SHADOW_DARK: ResourceColor;

  readonly STATUS_NEW: ResourceColor;
  readonly STATUS_LEARNING: ResourceColor;
  readonly STATUS_REVIEW: ResourceColor;
  readonly STATUS_RELEARNING: ResourceColor;

  readonly PURPLE: ResourceColor;
  readonly INDIGO: ResourceColor;
  readonly BROWN: ResourceColor;

  constructor(overrides?: Partial<ColorsInterface>) {
    this.PRIMARY = overrides?.PRIMARY ?? '#4DA3FF'; 
    this.PRIMARY_DARK = overrides?.PRIMARY_DARK ?? '#005BB5';
    this.PRIMARY_LIGHT = overrides?.PRIMARY_LIGHT ?? '#80C2FF';
    this.PRIMARY_LIGHTEST = overrides?.PRIMARY_LIGHTEST ?? '#1A3350';

    this.SECONDARY = overrides?.SECONDARY ?? '#E57373';
    this.SECONDARY_DARK = overrides?.SECONDARY_DARK ?? '#D32F2F';
    this.SECONDARY_LIGHT = overrides?.SECONDARY_LIGHT ?? '#FFCDD2';
    this.SECONDARY_LIGHTEST = overrides?.SECONDARY_LIGHTEST ?? '#3E2723';

    this.SUCCESS = overrides?.SUCCESS ?? '#81C784';
    this.SUCCESS_DARK = overrides?.SUCCESS_DARK ?? '#388E3C';
    this.SUCCESS_LIGHT = overrides?.SUCCESS_LIGHT ?? '#A5D6A7';
    this.SUCCESS_LIGHTEST = overrides?.SUCCESS_LIGHTEST ?? '#1B5E20';

    this.ERROR = overrides?.ERROR ?? '#E57373';
    this.ERROR_DARK = overrides?.ERROR_DARK ?? '#D32F2F';
    this.ERROR_LIGHT = overrides?.ERROR_LIGHT ?? '#FFCDD2';
    this.ERROR_LIGHTEST = overrides?.ERROR_LIGHTEST ?? '#3E2723';

    this.WARNING = overrides?.WARNING ?? '#FFF176';
    this.WARNING_DARK = overrides?.WARNING_DARK ?? '#FBC02D';
    this.WARNING_LIGHT = overrides?.WARNING_LIGHT ?? '#FFF59D';
    this.WARNING_LIGHTEST = overrides?.WARNING_LIGHTEST ?? '#F57F17';

    this.INFO = overrides?.INFO ?? '#4DD0E1';
    this.INFO_DARK = overrides?.INFO_DARK ?? '#0097A7';
    this.INFO_LIGHT = overrides?.INFO_LIGHT ?? '#80DEEA';
    this.INFO_LIGHTEST = overrides?.INFO_LIGHTEST ?? '#006064';

    this.WHITE = overrides?.WHITE ?? '#FFFFFF';
    this.BLACK = overrides?.BLACK ?? '#000000';
    
    this.GRAY_50 = overrides?.GRAY_50 ?? '#212121';
    this.GRAY_100 = overrides?.GRAY_100 ?? '#424242';
    this.GRAY_200 = overrides?.GRAY_200 ?? '#616161';
    this.GRAY_300 = overrides?.GRAY_300 ?? '#757575';
    this.GRAY_400 = overrides?.GRAY_400 ?? '#9E9E9E';
    this.GRAY_500 = overrides?.GRAY_500 ?? '#BDBDBD';
    this.GRAY_600 = overrides?.GRAY_600 ?? '#E0E0E0';
    this.GRAY_700 = overrides?.GRAY_700 ?? '#EEEEEE';
    this.GRAY_800 = overrides?.GRAY_800 ?? '#F5F5F5';
    this.GRAY_900 = overrides?.GRAY_900 ?? '#FAFAFA';

    this.BACKGROUND_PRIMARY = overrides?.BACKGROUND_PRIMARY ?? '#121212';
    this.BACKGROUND_SECONDARY = overrides?.BACKGROUND_SECONDARY ?? '#1E1E1E';
    this.BACKGROUND_TERTIARY = overrides?.BACKGROUND_TERTIARY ?? '#2C2C2C';
    this.SURFACE_PRIMARY = overrides?.SURFACE_PRIMARY ?? '#1E1E1E';
    this.SURFACE_ELEVATED = overrides?.SURFACE_ELEVATED ?? '#2C2C2C';

    this.TEXT_PRIMARY = overrides?.TEXT_PRIMARY ?? '#EEEEEE';
    this.TEXT_SECONDARY = overrides?.TEXT_SECONDARY ?? '#BDBDBD';
    this.TEXT_TERTIARY = overrides?.TEXT_TERTIARY ?? '#9E9E9E';
    this.TEXT_DISABLED = overrides?.TEXT_DISABLED ?? '#757575';

    this.BORDER_LIGHT = overrides?.BORDER_LIGHT ?? '#424242';
    this.BORDER_MEDIUM = overrides?.BORDER_MEDIUM ?? '#616161';
    this.BORDER_DARK = overrides?.BORDER_DARK ?? '#757575';

    this.SHADOW_LIGHT = overrides?.SHADOW_LIGHT ?? '#FFFFFF0D';
    this.SHADOW_MEDIUM = overrides?.SHADOW_MEDIUM ?? '#FFFFFF14';
    this.SHADOW_DARK = overrides?.SHADOW_DARK ?? '#FFFFFF1F';

    this.STATUS_NEW = overrides?.STATUS_NEW ?? '#4DA3FF';
    this.STATUS_LEARNING = overrides?.STATUS_LEARNING ?? '#E57373';
    this.STATUS_REVIEW = overrides?.STATUS_REVIEW ?? '#BA68C8';
    this.STATUS_RELEARNING = overrides?.STATUS_RELEARNING ?? '#F06292';

    this.PURPLE = overrides?.PURPLE ?? '#BA68C8';
    this.INDIGO = overrides?.INDIGO ?? '#7986CB';
    this.BROWN = overrides?.BROWN ?? '#A1887F';
  }
}
