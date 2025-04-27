# Scent Mate

An experimental Flutter application that suggests personalized fragrances based on user preferences. This project is part of a vibe coding experiment, where the focus is on creating an immersive and intuitive fragrance discovery experience.

## 🚀 Live Demo

A live version of the application is available at: [https://twinpixel.github.io/scent_mate/](https://twinpixel.github.io/scent_mate/)

## 🎨 Vibe Coding Experiment

This project is an exploration of:
- Creating an immersive user experience through scent-based interactions
- Experimenting with AI-powered personalization
- Building a multi-sensory digital experience
- Exploring the intersection of technology and sensory perception

## Features

- Multi-language support (English, Italian, Spanish, French, Russian)
- Interactive questionnaire to understand user preferences
- AI-powered fragrance suggestions
- Detailed scent profiles with top, middle, and base notes
- Similar fragrance recommendations
- Direct links to purchase options

## Running the Application

### Prerequisites

- Flutter SDK (latest version)
- Chrome browser (for web development)
- API keys for Gemini and Mistral AI services

### Setup

1. Clone the repository:
```bash
git clone https://github.com/twinpixel/scent_mate.git
cd scent_mate
```

2. Create an `api-keys.json` file in the project root with your API keys:
```json
{
  "KEY_GEMINI": "your-gemini-api-key",
  "KEY_MISTRAL": "your-mistral-api-key"
}
```

3. Install dependencies:
```bash
flutter pub get
```

### Running the App

#### Web (Chrome)
```bash
flutter run -d chrome --dart-define=API_KEY=api-keys.json
```

#### Android
```bash
flutter run -d android --dart-define=API_KEY=api-keys.json
```

#### iOS
```bash
flutter run -d ios --dart-define=API_KEY=api-keys.json
```

## Development

The application uses:
- Flutter for the UI framework
- SharedPreferences for local storage
- HTTP package for API calls
- Material Design 3 for the UI components

## 🚀 Experimental Features

- AI-powered scent profile generation
- Multi-language support with cultural scent preferences
- Experimental UI/UX patterns for scent visualization
- Real-time fragrance recommendations

## License

This project is licensed under the BSD 3-Clause License. See the [LICENSE](LICENSE) file for details.

Copyright (c) 2024 Andrea Poltronieri

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

## Author

Andrea Poltronieri - [http://www.andreapoltronieri.name](http://www.andreapoltronieri.name)