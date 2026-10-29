// Local vector icons stay crisp at every screen size and zoom level.
(()=>{
const paths={
 grid:'M3 3h7v7H3z M14 3h7v7h-7z M3 14h7v7H3z M14 14h7v7h-7z',
 clock:'M12 8v4l3 2 M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0',
 list:'M9 5h12 M9 12h12 M9 19h12 M3 5h.01 M3 12h.01 M3 19h.01',
 board:'M3 3h18v18H3z M9 3v18 M15 3v18 M5 7h2 M11 7h2 M17 7h2 M5 11h2 M11 11h2',
 calendar:'M4 5h16v16H4z M8 3v4 M16 3v4 M4 10h16 M8 14h.01 M12 14h.01 M16 14h.01 M8 18h.01 M12 18h.01',
 table:'M3 4h18v16H3z M3 9h18 M3 14h18 M9 4v16',
 gantt:'M4 3v18h17 M8 6h7 M11 11h9 M7 16h7',
 folder:'M3 7V5h6l2 2h10v13H3z',
 plus:'M12 5v14 M5 12h14',check:'M5 12l4 4L19 6',
 filter:'M4 7h16 M4 17h16 M8 4v6 M16 14v6',
 bell:'M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9 M10 21h4',
 menu:'M4 6h16 M4 12h16 M4 18h16',close:'M6 6l12 12 M18 6 6 18',
 spark:'M12 3l3 6 6 3-6 3-3 6-3-6-6-3 6-3z',
 download:'M12 3v12 M7 10l5 5 5-5 M4 16v5h16v-5'
};
const targets={'#all':'grid','#mine':'clock','#teamTasks':'list','#list':'list','#board':'board','#calendar':'calendar','#table':'table','#gantt':'gantt','#new':'plus','#addProject':'plus','.filter-toggle':'filter','.notification-bell':'bell','.menu-toggle':'menu','#close':'close','.edit-close':'close','.close-alerts':'close','.team-close':'close','.project b':'folder','.empty-icon':'spark','#export':'download','#backup':'download'};
function icon(name){const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('fill','none');svg.setAttribute('stroke','currentColor');svg.setAttribute('stroke-width','1.8');svg.setAttribute('stroke-linecap','round');svg.setAttribute('stroke-linejoin','round');svg.setAttribute('aria-hidden','true');svg.setAttribute('focusable','false');svg.classList.add('ui-icon');const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',paths[name]);svg.append(path);return svg}
function decorate(element,name){if(element.querySelector(':scope > .ui-icon'))return;const node=[...element.childNodes].find(n=>n.nodeType===3&&n.textContent.trim());if(node)node.textContent=node.textContent.replace(/^\s*[▦◷☷▥▤⚙♧☰✕▧＋+↓✓◔✧⌕]\s*/u,'');element.prepend(icon(name))}
function refresh(){for(const [selector,name] of Object.entries(targets))document.querySelectorAll(selector).forEach(el=>decorate(el,name));document.querySelectorAll('.stat .symbol').forEach((el,i)=>decorate(el,['grid','clock','clock','check'][i%4]))}
let scheduled=false;new MutationObserver(()=>{if(!scheduled){scheduled=true;requestAnimationFrame(()=>{scheduled=false;refresh()})}}).observe(document.body,{childList:true,subtree:true,characterData:true});refresh();
})();
