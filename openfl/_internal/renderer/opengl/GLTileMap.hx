package openfl._internal.renderer.opengl;


import lime.graphics.GLRenderContext;
import lime.graphics.opengl.GLBuffer;
import lime.graphics.opengl.GLProgram;
import lime.graphics.opengl.GLTexture;
import lime.graphics.opengl.GLUniformLocation;
import lime.math.Matrix4;
import lime.utils.Float32Array;
import lime.utils.GLUtils;
import openfl._internal.renderer.opengl.GLTileMap;
import openfl._internal.renderer.RenderSession;
import openfl._internal.renderer.RenderSession;
import openfl.display.TileMap;

@:access(openfl.display.TileMap)
@:access(openfl.display.TileMapLayer)
@:access(openfl.display.TileSet)


class GLTileMap {
	
	
	private static var glImageUniform:GLUniformLocation;
	private static var glMatrix:Matrix4;
	private static var glMatrixUniform:GLUniformLocation;
	private static var glProgram:GLProgram;
	private static var glTextureAttribute:Int;
	private static var glVertexAttribute:Int;
	
	
	private static function initialize (gl:GLRenderContext):Void {
		
		if (glProgram == null) {
			
			var vertexSource = "
				
				attribute vec2 aVertexPosition;
				attribute vec2 aTexCoord;
				uniform mat4 uMatrix;
				varying vec2 vTexCoord;
				
				void main (void) {
					
					vTexCoord = aTexCoord;
					gl_Position = uMatrix * vec4 (aVertexPosition, 0.0, 1.0);
					
				}
				
			";
			
			var fragmentSource = 
				
				#if (!desktop || rpi)
				"precision mediump float;" +
				#end
				"varying vec2 vTexCoord;
				uniform sampler2D uImage0;
				
				void main (void) {
					
					gl_FragColor = texture2D (uImage0, vTexCoord);
					
				}
				
			";
			
			glProgram = GLUtils.createProgram (vertexSource, fragmentSource);
			
			// TODO: Handle width/height
			
			glMatrix = Matrix4.createOrtho (0, 800, 600, 0, -1000, 1000);
			
			glVertexAttribute = gl.getAttribLocation (glProgram, "aVertexPosition");
			glTextureAttribute = gl.getAttribLocation (glProgram, "aTexCoord");
			glMatrixUniform = gl.getUniformLocation (glProgram, "uMatrix");
			glImageUniform = gl.getUniformLocation (glProgram, "uImage0");
			
		}
		
	}
	
	
	public static inline function render (tileMap:TileMap, renderSession:RenderSession):Void {
		
		if (tileMap.__layers == null || tileMap.__layers.length == 0) return;
		
		renderSession.shaderManager.setShader (null);
		renderSession.blendModeManager.setBlendMode (null);
		
		var gl = renderSession.gl;
		
		initialize (gl);
		
		gl.useProgram (glProgram);
		
		gl.enableVertexAttribArray (glVertexAttribute);
		gl.enableVertexAttribArray (glTextureAttribute);
		
		gl.activeTexture (gl.TEXTURE0);
		
		#if (desktop && !rpi)
		gl.enable (gl.TEXTURE_2D);
		#end
		
		var tiles, count, bufferData, buffer, previousLength, offset;
		var cacheTileID = -1, tileWidth = 0, tileHeight = 0;
		var tile, x, y, x2, y2;
		
		// TODO: Support tiles that are not the full tileset size
		
		for (layer in tileMap.__layers) {
			
			if (layer.__tiles.length == 0 || layer.tileSet == null || layer.tileSet.bitmapData == null) continue;
			
			gl.bindTexture (gl.TEXTURE_2D, layer.tileSet.bitmapData.getTexture (gl));
			
			tiles = layer.__tiles;
			count = tiles.length;
			
			bufferData = layer.__bufferData;
			
			if (bufferData == null || bufferData.length != count * 24) {
				
				previousLength = 0;
				
				if (bufferData == null) {
					
					bufferData = new Float32Array (count * 24);
					
				} else {
					
					previousLength = Std.int (bufferData.length / 24);
					
					var data = new Float32Array (count * 24);
					
					for (i in 0...bufferData.length) {
						
						data[i] = bufferData[i];
						
					}
					
					bufferData = data;
					
				}
				
				for (i in previousLength...count) {
					
					offset = i * 24;
					
					bufferData[offset + 2] = 0;
					bufferData[offset + 3] = 0;
					bufferData[offset + 6] = 1;
					bufferData[offset + 7] = 0;
					bufferData[offset + 10] = 0;
					bufferData[offset + 11] = 1;
					
					bufferData[offset + 14] = 0;
					bufferData[offset + 15] = 1;
					bufferData[offset + 18] = 1;
					bufferData[offset + 19] = 0;
					bufferData[offset + 22] = 1;
					bufferData[offset + 23] = 1;
					
				}
				
				layer.__bufferData = bufferData;
				
			}
			
			if (layer.__buffer == null) {
				
				layer.__buffer = gl.createBuffer ();
				
			}
			
			gl.bindBuffer (gl.ARRAY_BUFFER, layer.__buffer);
			
			for (i in 0...count) {
				
				tile = tiles[i];
				
				if (tile.id != cacheTileID) {
					
					tileWidth = Std.int (layer.tileSet.__rects[tile.id].width);
					tileHeight = Std.int (layer.tileSet.__rects[tile.id].height);
					cacheTileID = tile.id;
					
				}
				
				offset = i * 24;
				
				// TODO: Use dirty flag on tiles?
				
				x = tile.x;
				y = tile.y;
				x2 = x + tileWidth;
				y2 = y + tileHeight;
				
				bufferData[offset + 0] = x;
				bufferData[offset + 1] = y;
				bufferData[offset + 4] = x2;
				bufferData[offset + 5] = y;
				bufferData[offset + 8] = x;
				bufferData[offset + 9] = y2;
				
				bufferData[offset + 12] = x;
				bufferData[offset + 13] = y2;
				bufferData[offset + 16] = x2;
				bufferData[offset + 17] = y;
				bufferData[offset + 20] = x2;
				bufferData[offset + 21] = y2;
				
			}
			
			gl.bufferData (gl.ARRAY_BUFFER, bufferData, gl.STATIC_DRAW);
			
			gl.vertexAttribPointer (glVertexAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 0);
			gl.vertexAttribPointer (glTextureAttribute, 2, gl.FLOAT, false, 4 * Float32Array.BYTES_PER_ELEMENT, 2 * Float32Array.BYTES_PER_ELEMENT);
			
			gl.uniformMatrix4fv (glMatrixUniform, false, glMatrix);
			gl.uniform1i (glImageUniform, 0);
			
			gl.drawArrays (gl.TRIANGLES, 0, tiles.length * 6);
			
		}
		
		gl.bindBuffer (gl.ARRAY_BUFFER, null);
		gl.bindTexture (gl.TEXTURE_2D, null);
		
		#if (desktop && !rpi)
		gl.disable (gl.TEXTURE_2D);
		#end
		
		gl.disableVertexAttribArray (glVertexAttribute);
		gl.disableVertexAttribArray (glTextureAttribute);
		
		gl.useProgram (null);
		
	}
	
	
}