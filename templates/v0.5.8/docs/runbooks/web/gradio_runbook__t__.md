# Gradio Operations Runbook

## Overview

Gradio is a Python framework for building ML model interfaces and demos. Create shareable web apps in minutes.

**Key features:**
- Simplest for ML models
- Built-in sharing (gradio.app)
- Input/output focused
- Blocks API for custom layouts

**Best for:** ML model demos, quick prototypes, sharing with non-technical users

---

## Installation

```bash
pip install gradio

# Create first app
python -c "import gradio as gr; gr.Interface(lambda x: x, 'text', 'text').launch()"
```

---

## Basic Interface

```python
import gradio as gr

def greet(name):
    return f"Hello {name}!"

demo = gr.Interface(
    fn=greet,
    inputs=gr.Textbox(label="Name"),
    outputs=gr.Textbox(label="Greeting"),
    title="Greeter",
    description="Enter your name"
)

demo.launch()
```

---

## Input Components

```python
import gradio as gr

def process(text, number, slider, dropdown, checkbox, radio, image, audio, video, file):
    return "Processed!"

demo = gr.Interface(
    fn=process,
    inputs=[
        gr.Textbox(label="Text"),
        gr.Number(label="Number"),
        gr.Slider(0, 100, label="Slider"),
        gr.Dropdown(["A", "B", "C"], label="Dropdown"),
        gr.Checkbox(label="Checkbox"),
        gr.Radio(["Option 1", "Option 2"], label="Radio"),
        gr.Image(label="Image"),
        gr.Audio(label="Audio"),
        gr.Video(label="Video"),
        gr.File(label="File")
    ],
    outputs="text"
)

demo.launch()
```

---

## ML Model Example

```python
import gradio as gr
from transformers import pipeline

# Load model
classifier = pipeline("sentiment-analysis")

def analyze_sentiment(text):
    result = classifier(text)[0]
    return f"{result['label']}: {result['score']:.2%}"

demo = gr.Interface(
    fn=analyze_sentiment,
    inputs=gr.Textbox(lines=5, placeholder="Enter text..."),
    outputs=gr.Label(num_top_classes=2),
    title="Sentiment Analysis",
    examples=[
        ["I love this!"],
        ["This is terrible."]
    ]
)

demo.launch()
```

---

## Blocks API (Custom Layouts)

```python
import gradio as gr

with gr.Blocks() as demo:
    gr.Markdown("# Image Classifier")
    
    with gr.Row():
        with gr.Column():
            image = gr.Image(type="pil")
            btn = gr.Button("Classify")
        
        with gr.Column():
            label = gr.Label(num_top_classes=3)
    
    btn.click(fn=classify_image, inputs=image, outputs=label)

demo.launch()
```

---

## Sharing

```python
# Share publicly (temporary link)
demo.launch(share=True)

# Output: Running on public URL: https://xxxxx.gradio.live
```

---

## Deployment

### Hugging Face Spaces (Free)

1. Create space at https://huggingface.co/spaces
2. Add files:
```
app.py
requirements.txt
```

3. **app.py:**
```python
import gradio as gr

def greet(name):
    return f"Hello {name}!"

demo = gr.Interface(fn=greet, inputs="text", outputs="text")
demo.launch()
```

4. **requirements.txt:**
```
gradio==4.8.0
```

### Docker

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 7860
CMD ["python", "app.py"]
```

---

## References

- **Documentation:** https://gradio.app/docs/
- **Guides:** https://gradio.app/guides/
- **Spaces:** https://huggingface.co/spaces

---

## Related Documentation

- **UI Guide:** `docs/guides/ui_guide__t__.md`
- **Streamlit Runbook:** `streamlit_runbook__t__.md`
