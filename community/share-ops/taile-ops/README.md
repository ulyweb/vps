> [!NOTE]
> # Here are the three deliverables files:
---

> ## sra-skin-install.sh — bash -n passes clean, no syntax errors.                                                                                      
  
> ## SRA-SYSTEM-PROMPT.md — The AI job description covering:                                                                                            
  - Infrastructure map (container → NPM → UFW)   
  - 10 golden rules (never ports:, dark mode parity, booking URL fallback, slider clip pattern, etc.)                                                
  - Full design system: color palette, typography, spacing                                           
  - Every section description with what it does and how it behaves                                                                                   
  - Placeholder injection system reference                                                                                                           
  - 6 known gotchas to avoid                                                                                                                         
                                                                                                                                                     
> ## SRA-ARTIFACT.md — The complete technical blueprint covering:                                                                                       
  - Full docker-compose.yml, nginx.conf                                                                                                              
  - Installer logic (escape function, monogram gen, booking URL logic)                                                                               
  - Every section with actual HTML snippets and CSS/JS code                                                                                          
  - Before/After slider clip-container pattern (the critical implementation detail)                                                                  
  - Testimonial carousel with full JS                                                                                                                
  - Customization cheat sheet                                                                                                                        
  - Deployment commands + troubleshooting table                                                                                                      
                                                                                                                                                     
You can take sra-skin-install.sh + these two docs. When they want to change something later, they hand both docs to their AI and the AI will have everything it needs without you having to re-explain anything.   


> [!TIP]
> # Here are the exact prompts you use, depending on what they need:                                                                  
                                                                                                                                                   
  ---                                                                                                                                                
First Time (Starting Fresh)
                                                                                                                                                     
When they open a new chat with any AI (ChatGPT, Claude, etc.), they paste both files and say:
````                                                                                                                                                   
I'm setting up a luxury aesthetics studio website on my VPS. I've attached two files — the System Prompt is your job description and rules, the  
Artifact is the full technical blueprint of everything that was built. Read both before responding. My first question is: [their question here]
````                                                                                                                                                   
  ---                                                                                                                                              
Ongoing Sessions (After Site Is Live)                                                                                                            
````                                                                                                                                                     
I have a luxury aesthetics studio site deployed at skin.mydomain.com. It's a single HTML file at ~/skin/html/index.html served by an nginx:alpine
Docker container behind Nginx Proxy Manager on the npm_default network. I'm attaching the system prompt and artifact that document how it was   
built. Read both, then help me: [their task] 
````                                                                                                                                                     
  ---                                            
Specific Task Examples                                                                                                                           
                        
To change something on the site:
````                                                                                                                                                     
Using the attached system prompt and artifact — I want to change the hero background image to a photo I have. Where exactly in index.html do I   
find it and what do I replace?                                                                                                                   
````                                                                                                                                                     
To add a new section:                                                                                                                              
````                                                                                                                                                   
Using the attached docs — I want to add a pricing section after the services grid. Follow the same design system (colors, fonts, dark mode       
support). Give me the HTML and CSS to paste in.
````                                                                                                                                                     
To fix something broken:                       
````                                                                                                                                                   
My before/after slider is squishing the before image. The attached artifact has the correct implementation. Can you show me exactly what the     
setSlider function should look like?
````                                                                                                                                                     
To add a new service:                                                                                                                              
````                                                                                                                                                   
I want to add a 7th service card for "IV Therapy". Using the attached artifact, show me the card HTML to copy and what CSS change I need for the grid.                                        
````                                                                                                                                                     
  ---                                            
> [!TIP]
> # The Key Rule                                                                                                                        
````                                                                                                                                                     
Always attach both files at the start of every new chat session. AIs don't remember previous conversations
the docs ARE the memory. Without them, the AI will give generic advice that may conflict with how the site was actually built.                                      
````                                                 
If they're using Claude.ai, they can upload both .md files directly into the chat as attachments. Same with ChatGPT — just attach them as files. 
