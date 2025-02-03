User Uploads or Selects a PDF in the Flutter app.

Backend:
- Indexing Pipeline:
  - Splits PDF into chunks (e.g., 512-1000 tokens each).
  - Embeds them (e.g. using Sentence Transformers).
  - Stores them in a DocumentStore (e.g. InMemory or FAISS or Elasticsearch).
- Query / RAG Pipeline:
  - Accepts user’s query & context (like page number, AiCharacter, current progress).
  - Retrieves relevant chunks from the DocumentStore (up to user’s current page).
  - Builds a prompt (integrating AiCharacter and “no spoiler” logic if needed).
  - Sends to an LLM generator (OpenAI, local model, or any).
  - Returns a final text answer.
- Return Response to the Flutter app, which displays the AI’s answer in your chat UI or elsewhere.
Example user backend service flow:
- User taps a button “Add PDF” -> calls FileUtils.picker().
- If successful, the PDF is automatically uploaded.
- The user sees a success message.
- The user opens a “chat” screen or a “query” screen. They input a question, and your code calls:
    - final answer = await RagService.queryRag(
        - userQuery: userQuestion,
        - selectedText: excerptFromPdf,
        - bookTitle: "My Book",
        - pageNumber: 12,
        - totalPages: 230,
        - aiName: "BobBot",
        - aiPersonality: "Friendly",
        );
- Display answer in a chat bubble.

