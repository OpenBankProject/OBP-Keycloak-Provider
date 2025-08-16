# OBP Keycloak Theme Documentation

## Overview

The OBP (Open Bank Project) Keycloak theme provides a modern, branded user interface that matches the Open Bank Project Portal design system. This theme transforms the default Keycloak login experience to align with OBP's visual identity and user experience standards.

## Theme Features

### Visual Design
- **Modern Dark Theme**: Elegant dark background with gradient overlays
- **OBP Branding**: Official OBP logos and color scheme
- **Glassmorphism UI**: Translucent cards with backdrop blur effects
- **Responsive Design**: Mobile-first approach with tablet and desktop optimization

### Color System
- **Primary Colors**: Dark blue/gray palette (OKLCH color space)
- **Secondary Colors**: Teal/green accent colors
- **Surface Colors**: Sophisticated gray scale
- **State Colors**: Success (green), error (red), warning (orange)

### Typography
- **Font Family**: Plus Jakarta Sans (Google Fonts)
- **Font Weights**: 200-800 range with italic support
- **Letter Spacing**: Optimized for readability (0.01em)
- **Text Scaling**: 1.067 ratio for harmonious typography

### User Experience
- **Smooth Animations**: CSS transitions for hover and focus states
- **Accessibility**: High contrast support, reduced motion preferences
- **Form Controls**: Modern input fields with floating labels
- **Button Styling**: Consistent primary and secondary button designs
- **Loading States**: Visual feedback for form submissions

## File Structure

```
themes/obp/
├── theme.properties                    # Theme configuration
├── login/                             # Login theme files
│   ├── login.ftl                      # Custom login template
│   ├── messages/                      # Internationalization
│   │   └── messages_en.properties     # English messages
│   └── resources/                     # Static resources
│       ├── css/
│       │   └── styles.css             # Main stylesheet
│       └── img/                       # Images and logos
│           ├── obp_logo.png          # Main OBP logo
│           ├── logo2x-1.png          # Alternative logo
│           └── favicon.png           # Favicon
```

## Color Palette

### Primary Colors (Dark Blue/Gray)
```css
--obp-primary-500: oklch(26.42% 0.02 280.83deg)  /* Main brand color */
--obp-primary-950: oklch(14.97% 0.03 285.58deg)  /* Darkest shade */
```

### Secondary Colors (Teal/Green)
```css
--obp-secondary-500: oklch(68.5% 0.14 148.36deg)   /* Accent color */
--obp-secondary-600: oklch(58.64% 0.12 148.32deg)  /* Button hover */
```

### Surface Colors (Grays)
```css
--obp-surface-50: oklch(100% 0 none)      /* Pure white */
--obp-surface-950: oklch(0% 0 none)       /* Pure black */
```

## Component Styling

### Login Card
- **Background**: Semi-transparent with blur effect
- **Border**: Subtle white border with opacity
- **Shadow**: Deep shadow for elevation
- **Padding**: Responsive spacing (1.5rem mobile, 3rem desktop)
- **Width**: 28rem standard, 32rem desktop

### Form Controls
- **Background**: Translucent white with blur
- **Border**: Rounded corners (0.375rem radius)
- **Focus State**: Teal border with glow effect
- **Height**: Minimum 3rem for accessibility
- **Typography**: Plus Jakarta Sans, 1rem size

### Buttons
- **Primary**: Teal background with dark text
- **Secondary**: Transparent with white border
- **Hover Effects**: Transform and shadow animations
- **Typography**: Semibold weight, consistent sizing

## Deployment Options

### Standard Deployment
```bash
./sh/run-with-env.sh --standard
```

### Themed Deployment
```bash
./sh/run-with-env.sh --themed
```

## Theme Activation

1. **Build and Deploy**: Use themed deployment option
2. **Access Admin Console**: https://localhost:8443/admin
3. **Navigate to Realm Settings**: Select your realm
4. **Go to Themes Tab**: In realm settings
5. **Select Login Theme**: Choose "obp" from dropdown
6. **Save Changes**: Apply the theme

## Customization Guide

### Modifying Colors
Edit the CSS variables in `styles.css`:
```css
:root {
    --obp-primary-500: your-color-here;
    --obp-secondary-500: your-accent-color;
}
```

### Adding New Languages
1. Create new message file: `messages_[locale].properties`
2. Update `theme.properties` locales list
3. Translate all message keys

### Custom Logo
1. Replace `obp_logo.png` in `/img/` directory
2. Update CSS background-image path if needed
3. Adjust logo container dimensions if necessary

### Form Layout Changes
1. Modify `login.ftl` template
2. Add corresponding CSS in `styles.css`
3. Test responsive behavior

## Browser Support

### Modern Browsers
- **Chrome**: 88+ (full support)
- **Firefox**: 84+ (full support)
- **Safari**: 14+ (full support)
- **Edge**: 88+ (full support)

### Feature Support
- **CSS Custom Properties**: Required
- **Backdrop Filter**: Enhanced experience
- **OKLCH Colors**: Progressive enhancement
- **Grid/Flexbox**: Layout foundation

## Accessibility Features

### WCAG 2.1 Compliance
- **Color Contrast**: AA level compliance
- **Focus Indicators**: Visible focus outlines
- **Keyboard Navigation**: Full keyboard support
- **Screen Readers**: Semantic HTML structure

### Responsive Design
- **Mobile**: 320px minimum width
- **Tablet**: 768px breakpoint
- **Desktop**: 1024px+ optimization
- **High DPI**: Retina display support

## Performance Optimizations

### CSS Optimizations
- **Variables**: Efficient color management
- **Transitions**: Hardware-accelerated animations
- **Font Loading**: Google Fonts with display swap
- **Image Optimization**: Compressed PNG assets

### Loading Performance
- **Critical CSS**: Inline essential styles
- **Resource Hints**: Preload font files
- **Lazy Loading**: Non-critical images
- **Minification**: Production CSS compression

## Troubleshooting

### Theme Not Appearing
1. Check theme files are in correct directory structure
2. Verify Keycloak has been restarted after theme installation
3. Ensure theme is selected in Admin Console
4. Check container logs for theme loading errors

### Styling Issues
1. Clear browser cache
2. Check CSS file paths in theme.properties
3. Verify image paths in CSS
4. Test in different browsers

### Build Errors
1. Ensure all theme files exist before build
2. Check Dockerfile copies theme directory correctly
3. Verify file permissions after container build
4. Review container logs for specific errors

## Development Workflow

### Local Development
1. **Edit Theme Files**: Modify CSS, templates, or messages
2. **Rebuild Container**: `./sh/run-with-env.sh --themed`
3. **Test Changes**: Access login page in browser
4. **Iterate**: Repeat until satisfied

### Testing Checklist
- [ ] Login page renders correctly
- [ ] Forms are functional
- [ ] Responsive design works
- [ ] All images load properly
- [ ] Error messages display correctly
- [ ] Social login buttons (if enabled)
- [ ] Multiple browsers tested

## Contributing

### Code Style
- **CSS**: Use CSS custom properties for colors
- **Templates**: Follow FreeMarker best practices
- **Messages**: Use descriptive, user-friendly text
- **Images**: Optimize for web delivery

### Pull Request Guidelines
1. Test theme thoroughly before submitting
2. Include screenshots of visual changes
3. Document any breaking changes
4. Update this documentation if needed

## Resources

### External Dependencies
- **Google Fonts**: Plus Jakarta Sans typography
- **Keycloak**: Base theme functionality
- **FreeMarker**: Template engine
- **CSS**: Modern features (custom properties, backdrop-filter)

### Useful Links
- [Keycloak Theme Documentation](https://www.keycloak.org/docs/latest/server_development/#_themes)
- [OBP Portal Repository](https://github.com/OpenBankProject/OBP-Portal)
- [Plus Jakarta Sans Font](https://fonts.google.com/specimen/Plus+Jakarta+Sans)
- [OKLCH Color Format](https://oklch.com/)

## Version History

### v1.0.0
- Initial OBP theme implementation
- Dark theme with modern UI
- Complete responsive design
- OBP branding integration
- Multi-language support foundation

---

*This theme is part of the Open Bank Project ecosystem. For support, please refer to the main project documentation or contact the development team.*