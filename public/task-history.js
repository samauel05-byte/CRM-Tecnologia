(function(){
const button=document.createElement('button');button.id='taskHistory';button.className='nav';button.innerHTML='<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 4v5h5M3 9a9 9 0 1 1 0 6m9-9v6l4 2"/></svg><span>Historial</span>';$('mine').after(button);
button.onclick=()=>{taskHistory=true;mine=false;selected='';view='list';for(const id of ['search','filter','statusFilter','ownerFilter'])$(id).value='';render()};
document.addEventListener('click',event=>{if(event.target.closest('#all,#mine,#teamTasks,[data-project],#new'))taskHistory=false},true);
const previousRender=render;
render=function(){previousRender();button.classList.toggle('active',taskHistory);$('new').style.display=taskHistory?'none':'';document.querySelector('.heading .eyebrow').textContent=taskHistory?'TRABAJO FINALIZADO':'UN BUEN DÍA PARA AVANZAR';document.querySelector('.heading p').textContent=taskHistory?'Las tareas finalizadas de Samuel y Elvis, reunidas en un solo lugar. Puedes consultarlas o reabrirlas.':'Todo lo que necesitas hacer, con claridad y a tu ritmo.';if(!taskHistory)return;$('renameProject').hidden=true;document.querySelectorAll('#tasks [data-add],#tasks .addrow').forEach(item=>item.remove());if(!visible().length)$('tasks').innerHTML='<div class="empty-state"><span class="empty-icon" aria-hidden="true">✓</span><h2>Aún no hay tareas finalizadas</h2><p>Al completar una tarea, aparecerá aquí automáticamente. También puedes limpiar los filtros si no encuentras una tarea.</p></div>'};
render();
})();

