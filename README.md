



# Vastcount

An intelligent accounting assistant that uses AI to help with document processing, data extraction, and financial management.


## Features

- **Multi-Format Document Processing**: Process PDFs, images, and text files containing invoices and receipts
- **Template-Based Extraction**: Create custom templates for different document types
- **AI-Powered Analysis**: Leverage Google's Gemini 1.5 for intelligent data extraction
- **Dynamic Data Tables**: Filter, sort, and analyze extracted data
- **Gemini Columns**: Create AI-generated insights from your data
- **Export Functionality**: Export to CSV for use in other accounting software

## Getting Started

### Prerequisites

- Flutter 3.0+
- Firebase account
- Google Gemini API key

### Installation

1. Clone the repository
   ```
   git clone https://github.com/Yousif-GO/Vast-Count.git
   ```

2. Install dependencies
   ```
   flutter pub get
   ```

3. Create a `.env` file in the assets folder with your Gemini API key
   ```
   GEMINI_API_KEY=your_api_key_here
   ```

4. Set up Firebase:
   - Create a new Firebase project
   - Enable Authentication (Email/Password and Anonymous)
   - Set up Firestore Database
   - Add your app to Firebase and download the configuration files
   - Place the configuration files in the appropriate directories

5. Run the app
   ```
   flutter run
   ```

## Usage

### Creating Templates

1. Navigate to the "Templates" section
2. Click "Create New Template"
3. Name your template (e.g., "Invoice", "Receipt")
4. Add fields that you want to extract (e.g., "vendor", "date", "amount")
5. Save the template

### Processing Documents

1. Select a template from the dropdown
2. Choose your upload method:
   - Single PDF
   - Single Image
   - Multiple PDFs
   - Multiple Images
3. Upload your document(s)
4. Wait for AI processing to complete
5. Review the extracted data

### Working with Data Tables

1. Navigate to the "View Documents" section
2. Select a template to view its data
3. Use filters to narrow down results
4. Check boxes to calculate sums of numeric columns
5. Add Gemini columns for AI-powered insights:
   - Click "Add Gemini Column"
   - Select a source column
   - Write a prompt for what you want Gemini to analyze
   - Click "Create Column"

### Exporting Data

1. From the data table view, click "Export"
2. Choose CSV format
3. Save the file to your computer
4. Import into your accounting software

## Troubleshooting

- **Processing Errors**: If document processing fails, try uploading a clearer image or PDF
- **Missing Fields**: Ensure your template includes all fields you want to extract
- **Authentication Issues**: Verify your Firebase configuration is correct
- **API Key Errors**: Check that your Gemini API key is valid and properly set in the .env file

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed see the LICENSE file for details.

## Acknowledgments

- Google Gemini API for powering the AI extraction
- Firebase for authentication and database services
- Flutter team 

---

For support or inquiries, please open an issue on this repository.
