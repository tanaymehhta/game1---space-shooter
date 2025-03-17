import SpriteKit
import GameplayKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Properties
    
    private var playerShip: SKSpriteNode!
    private var touchPosition: CGPoint = .zero
    private var lastUpdateTime: TimeInterval = 0
    private var deltaTime: TimeInterval = 0
    
    private var gameScore = 0
    private var scoreLabel: SKLabelNode!
    private var healthBar: SKSpriteNode!
    private var playerHealth = 100
    
    private let bulletSpeed: CGFloat = 500
    private var lastFireTime: TimeInterval = 0
    private let fireRate: TimeInterval = 0.3
    
    private var lastEnemySpawnTime: TimeInterval = 0
    private var enemySpawnRate: TimeInterval = 1.5
    
    private struct PhysicsCategory {
        static let None: UInt32 = 0
        static let Player: UInt32 = 0b1
        static let PlayerBullet: UInt32 = 0b10
        static let Enemy: UInt32 = 0b100
        static let EnemyBullet: UInt32 = 0b1000
        static let Asteroid: UInt32 = 0b10000
    }
    
    private var isGameOver = false
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        setupPhysicsWorld()
        setupStarfield()
        setupPlayer()
        setupHUD()
        startSpawning()
    }
    
    // MARK: - Setup Methods
    
    private func setupPhysicsWorld() {
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }
    
    private func setupStarfield() {
        let starfieldNode = SKNode()
        addChild(starfieldNode)
        
        createStarLayer(parent: starfieldNode, count: 50, size: 1.0, speed: 0.1, color: .white)
        createStarLayer(parent: starfieldNode, count: 30, size: 2.0, speed: 0.2, color: SKColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0))
        createStarLayer(parent: starfieldNode, count: 15, size: 3.0, speed: 0.3, color: SKColor(red: 1.0, green: 1.0, blue: 0.8, alpha: 1.0))
    }
    
    private func createStarLayer(parent: SKNode, count: Int, size: CGFloat, speed: CGFloat, color: SKColor) {
        for _ in 0..<count {
            let star = SKShapeNode(circleOfRadius: size)
            star.fillColor = color
            star.strokeColor = .clear
            star.position = CGPoint(x: CGFloat.random(in: 0...frame.width), y: CGFloat.random(in: 0...frame.height))
            star.alpha = CGFloat.random(in: 0.5...1.0)
            parent.addChild(star)
            
            let moveDown = SKAction.moveBy(x: 0, y: -speed * frame.height, duration: 15)
            let resetPosition = SKAction.moveBy(x: 0, y: frame.height, duration: 0)
            star.run(SKAction.repeatForever(SKAction.sequence([moveDown, resetPosition])))
        }
    }
    
    private func setupPlayer() {
        playerShip = SKSpriteNode(color: .cyan, size: CGSize(width: 40, height: 60))
        playerShip.position = CGPoint(x: frame.midX, y: 100)
        playerShip.zPosition = 10
        
        let engineGlow = createEngineParticle()
        engineGlow.position = CGPoint(x: 0, y: -playerShip.size.height / 2)
        engineGlow.zPosition = -1
        playerShip.addChild(engineGlow)
        
        playerShip.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: playerShip.size.width * 0.8, height: playerShip.size.height * 0.8))
        playerShip.physicsBody?.isDynamic = true
        playerShip.physicsBody?.categoryBitMask = PhysicsCategory.Player
        playerShip.physicsBody?.contactTestBitMask = PhysicsCategory.Enemy | PhysicsCategory.EnemyBullet | PhysicsCategory.Asteroid
        playerShip.physicsBody?.collisionBitMask = PhysicsCategory.None
        playerShip.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(playerShip)
    }
    
    private func setupHUD() {
        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 24
        scoreLabel.fontColor = .white
        scoreLabel.position = CGPoint(x: 100, y: frame.height - 40)
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.text = "Score: 0"
        scoreLabel.zPosition = 100
        addChild(scoreLabel)
        
        let healthBarBackground = SKSpriteNode(color: .darkGray, size: CGSize(width: 200, height: 20))
        healthBarBackground.position = CGPoint(x: frame.width - 120, y: frame.height - 40)
        healthBarBackground.zPosition = 100
        addChild(healthBarBackground)
        
        healthBar = SKSpriteNode(color: .green, size: CGSize(width: 200, height: 20))
        healthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        healthBar.position = CGPoint(x: healthBarBackground.position.x - 100, y: healthBarBackground.position.y)
        healthBar.zPosition = 101
        addChild(healthBar)
    }
    
    private func startSpawning() {
        let spawnEnemies = SKAction.repeatForever(SKAction.sequence([
            SKAction.run(spawnEnemy),
            SKAction.wait(forDuration: enemySpawnRate)
        ]))
        
        let spawnAsteroids = SKAction.repeatForever(SKAction.sequence([
            SKAction.run(spawnAsteroid),
            SKAction.wait(forDuration: 3.0)
        ]))
        
        run(spawnEnemies, withKey: "spawnEnemies")
        run(spawnAsteroids, withKey: "spawnAsteroids")
    }
    
    // MARK: - Particle Effects
    
    private func createEngineParticle() -> SKEmitterNode {
        let particle = SKEmitterNode()
        particle.particleBirthRate = 100
        particle.particleLifetime = 0.8
        particle.particlePositionRange = CGVector(dx: 10, dy: 0)
        particle.particleSpeed = 50
        particle.particleSpeedRange = 20
        particle.particleAlpha = 1.0
        particle.particleAlphaRange = 0.2
        particle.particleAlphaSpeed = -1.0
        particle.particleScale = 0.1
        particle.particleScaleRange = 0.05
        particle.particleScaleSpeed = -0.1
        particle.emissionAngle = .pi * 1.5
        particle.emissionAngleRange = 0.3
        particle.particleColor = SKColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0)
        particle.particleBlendMode = .add
        return particle
    }
    
    private func createExplosionEmitter(at position: CGPoint, color: SKColor, size: CGSize) -> SKEmitterNode {
        let explosion = SKEmitterNode()
        explosion.position = position
        explosion.zPosition = 15
        explosion.particleBirthRate = 1000
        explosion.numParticlesToEmit = 100
        explosion.particleLifetime = 1.5
        explosion.particlePositionRange = CGVector(dx: 20, dy: 20)
        explosion.particleSpeed = 200
        explosion.particleSpeedRange = 150
        explosion.particleAlpha = 1.0
        explosion.particleAlphaRange = 0.2
        explosion.particleAlphaSpeed = -0.8
        explosion.particleScale = 0.3 * (size.width / 60)
        explosion.particleScaleRange = 0.2
        explosion.particleScaleSpeed = -0.2
        explosion.particleRotationRange = .pi * 2
        explosion.particleRotationSpeed = 2
        explosion.emissionAngleRange = .pi * 2
        explosion.particleColor = color
        explosion.particleBlendMode = .add
        return explosion
    }
    
    private func createImpactEmitter(at position: CGPoint, color: SKColor) -> SKEmitterNode {
        let impact = SKEmitterNode()
        impact.position = position
        impact.zPosition = 15
        impact.particleBirthRate = 500
        impact.numParticlesToEmit = 50
        impact.particleLifetime = 0.5
        impact.particlePositionRange = CGVector(dx: 10, dy: 10)
        impact.particleSpeed = 100
        impact.particleSpeedRange = 80
        impact.particleAlpha = 1.0
        impact.particleAlphaRange = 0.3
        impact.particleAlphaSpeed = -2.0
        impact.particleScale = 0.15
        impact.particleScaleRange = 0.1
        impact.particleScaleSpeed = -0.3
        impact.emissionAngleRange = .pi * 2
        impact.particleColor = color
        impact.particleBlendMode = .add
        return impact
    }
    
    // MARK: - Game Elements
    
    private func fireBullet() {
        let bullet = SKSpriteNode(color: .cyan, size: CGSize(width: 4, height: 16))
        bullet.position = CGPoint(x: playerShip.position.x, y: playerShip.position.y + playerShip.size.height / 2)
        bullet.zPosition = 5
        
        let glow = SKEffectNode()
        glow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 5.0])
        let glowSprite = SKSpriteNode(color: .cyan, size: CGSize(width: bullet.size.width * 2, height: bullet.size.height * 2))
        glowSprite.alpha = 0.6
        glow.addChild(glowSprite)
        bullet.addChild(glow)
        
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.PlayerBullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.Enemy | PhysicsCategory.Asteroid
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.None
        
        addChild(bullet)
        
        let moveAction = SKAction.moveBy(x: 0, y: frame.height + bullet.size.height, duration: frame.height / bulletSpeed)
        bullet.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
    }
    
    private func spawnEnemy() {
        let enemy = SKSpriteNode(color: Bool.random() ? .red : .orange, size: CGSize(width: 40, height: 50))
        enemy.position = CGPoint(x: CGFloat.random(in: enemy.size.width / 2...frame.width - enemy.size.width / 2), y: frame.height + enemy.size.height / 2)
        enemy.zPosition = 5
        
        enemy.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: enemy.size.width * 0.8, height: enemy.size.height * 0.8))
        enemy.physicsBody?.isDynamic = true
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.Enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.Player | PhysicsCategory.PlayerBullet
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.None
        
        addChild(enemy)
        
        let duration = TimeInterval.random(in: 4.0...7.0)
        let moveAction = SKAction.moveBy(x: 0, y: -(frame.height + enemy.size.height), duration: duration)
        
        if Bool.random() {
            let fireAction = SKAction.run { [weak self] in self?.enemyFireBullet(from: enemy) }
            let fireSequence = SKAction.sequence([SKAction.wait(forDuration: 1.0), fireAction])
            enemy.run(SKAction.group([moveAction, SKAction.repeat(fireSequence, count: Int(duration))]))
        } else {
            enemy.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
        }
    }
    
    private func enemyFireBullet(from enemy: SKSpriteNode) {
        let bullet = SKSpriteNode(color: .red, size: CGSize(width: 4, height: 16))
        bullet.position = CGPoint(x: enemy.position.x, y: enemy.position.y - enemy.size.height / 2)
        bullet.zPosition = 5
        
        let glow = SKEffectNode()
        glow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 5.0])
        let glowSprite = SKSpriteNode(color: .red, size: CGSize(width: bullet.size.width * 2, height: bullet.size.height * 2))
        glowSprite.alpha = 0.6
        glow.addChild(glowSprite)
        bullet.addChild(glow)
        
        bullet.physicsBody = SKPhysicsBody(rectangleOf: bullet.size)
        bullet.physicsBody?.isDynamic = true
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.EnemyBullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.Player
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.None
        
        addChild(bullet)
        
        let moveAction = SKAction.moveBy(x: 0, y: -(frame.height + bullet.size.height), duration: 2.0)
        bullet.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
    }
    
    private func spawnAsteroid() {
        let sizes: [String: CGSize] = ["small": CGSize(width: 30, height: 30), "medium": CGSize(width: 60, height: 60), "large": CGSize(width: 90, height: 90)]
        let sizeType = ["small", "medium", "large"].randomElement()!
        let asteroidSize = sizes[sizeType]!
        
        let asteroid = SKSpriteNode(color: .gray, size: asteroidSize)
        asteroid.name = sizeType
        asteroid.position = CGPoint(x: CGFloat.random(in: asteroidSize.width / 2...frame.width - asteroidSize.width / 2), y: frame.height + asteroidSize.height / 2)
        asteroid.zPosition = 5
        
        asteroid.physicsBody = SKPhysicsBody(circleOfRadius: asteroidSize.width / 2 * 0.8)
        asteroid.physicsBody?.isDynamic = true
        asteroid.physicsBody?.categoryBitMask = PhysicsCategory.Asteroid
        asteroid.physicsBody?.contactTestBitMask = PhysicsCategory.Player | PhysicsCategory.PlayerBullet
        asteroid.physicsBody?.collisionBitMask = PhysicsCategory.None
        
        let rotationAction = SKAction.rotate(byAngle: .pi * 2, duration: TimeInterval.random(in: 3...6))
        asteroid.run(SKAction.repeatForever(rotationAction))
        
        addChild(asteroid)
        
        let duration = TimeInterval.random(in: 4.0...8.0)
        let xOffset = CGFloat.random(in: -100...100)
        let moveAction = SKAction.move(by: CGVector(dx: xOffset, dy: -(frame.height + asteroidSize.height)), duration: duration)
        asteroid.run(SKAction.sequence([moveAction, SKAction.removeFromParent()]))
    }
    
    // MARK: - Update Loop
    
    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver else { return }
        
        deltaTime = lastUpdateTime > 0 ? currentTime - lastUpdateTime : 0
        lastUpdateTime = currentTime
        
        if touchPosition != .zero {
            let dx = touchPosition.x - playerShip.position.x
            if abs(dx) > 1 {
                playerShip.position.x += dx * 0.1
                playerShip.zRotation = min(max(-dx * 0.0003, -0.3), 0.3)
            }
        } else {
            playerShip.zRotation = 0
        }
        
        if currentTime - lastFireTime > fireRate {
            lastFireTime = currentTime
            fireBullet()
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isGameOver {
            restartGame()
        } else {
            touchPosition = CGPoint(x: location.x, y: playerShip.position.y)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, let touch = touches.first else { return }
        let location = touch.location(in: self)
        touchPosition = CGPoint(x: location.x, y: playerShip.position.y)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Continue moving towards last touch position
    }
    
    // MARK: - Collision Handling
    
    func didBegin(_ contact: SKPhysicsContact) {
        let firstBody = contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask ? contact.bodyA : contact.bodyB
        let secondBody = contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask ? contact.bodyB : contact.bodyA
        
        if let firstNode = firstBody.node as? SKSpriteNode, let secondNode = secondBody.node as? SKSpriteNode {
            switch (firstBody.categoryBitMask, secondBody.categoryBitMask) {
            case (PhysicsCategory.PlayerBullet, PhysicsCategory.Enemy):
                bulletHitEnemy(bullet: firstNode, enemy: secondNode)
            case (PhysicsCategory.PlayerBullet, PhysicsCategory.Asteroid):
                bulletHitAsteroid(bullet: firstNode, asteroid: secondNode)
            case (PhysicsCategory.Player, PhysicsCategory.EnemyBullet):
                enemyBulletHitPlayer(player: firstNode, bullet: secondNode)
            case (PhysicsCategory.Player, PhysicsCategory.Enemy):
                enemyHitPlayer(player: firstNode, enemy: secondNode)
            case (PhysicsCategory.Player, PhysicsCategory.Asteroid):
                asteroidHitPlayer(player: firstNode, asteroid: secondNode)
            default:
                break
            }
        }
    }
    
    // MARK: - Collision Responses
    
    private func bulletHitEnemy(bullet: SKSpriteNode, enemy: SKSpriteNode) {
        let explosion = createExplosionEmitter(at: enemy.position, color: .orange, size: enemy.size)
        addChild(explosion)
        bullet.removeFromParent()
        enemy.removeFromParent()
        
        gameScore += 100
        scoreLabel.text = "Score: \(gameScore)"
        
        explosion.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.removeFromParent()]))
    }
    
    private func bulletHitAsteroid(bullet: SKSpriteNode, asteroid: SKSpriteNode) {
        let explosion = createExplosionEmitter(at: asteroid.position, color: .gray, size: asteroid.size)
        addChild(explosion)
        bullet.removeFromParent()
        
        gameScore += 50
        scoreLabel.text = "Score: \(gameScore)"
        
        if asteroid.size.width > 30 {
            spawnAsteroidFragments(from: asteroid)
        }
        asteroid.removeFromParent()
        
        explosion.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.removeFromParent()]))
    }
    
    private func spawnAsteroidFragments(from asteroid: SKSpriteNode) {
        for _ in 0..<2 {
            let fragmentSize = CGSize(width: asteroid.size.width / 2, height: asteroid.size.height / 2)
            let fragment = SKSpriteNode(color: .gray, size: fragmentSize)
            fragment.position = asteroid.position.offsetBy(dx: CGFloat.random(in: -20...20), dy: CGFloat.random(in: -20...20))
            fragment.zPosition = 5
            
            fragment.physicsBody = SKPhysicsBody(circleOfRadius: fragmentSize.width / 2 * 0.8)
            fragment.physicsBody?.isDynamic = true
            fragment.physicsBody?.categoryBitMask = PhysicsCategory.Asteroid
            fragment.physicsBody?.contactTestBitMask = PhysicsCategory.Player | PhysicsCategory.PlayerBullet
            fragment.physicsBody?.collisionBitMask = PhysicsCategory.None
            
            let rotationAction = SKAction.rotate(byAngle: .pi * 2, duration: TimeInterval.random(in: 2...4))
            fragment.run(SKAction.repeatForever(rotationAction))
            
            addChild(fragment)
            
            let moveAction = SKAction.move(by: CGVector(dx: CGFloat.random(in: -100...100), dy: -CGFloat.random(in: 100...300)), duration: 3.0)
            fragment.run(SKAction.sequence([moveAction, SKAction.fadeOut(withDuration: 0.5), SKAction.removeFromParent()]))
        }
    }
    
    private func enemyBulletHitPlayer(player: SKSpriteNode, bullet: SKSpriteNode) {
        bullet.removeFromParent()
        let impact = createImpactEmitter(at: player.position, color: .red)
        addChild(impact)
        
        damagePlayer(amount: 10)
        impact.run(SKAction.sequence([SKAction.wait(forDuration: 0.5), SKAction.removeFromParent()]))
    }
    
    private func enemyHitPlayer(player: SKSpriteNode, enemy: SKSpriteNode) {
        let explosion = createExplosionEmitter(at: enemy.position, color: .orange, size: enemy.size)
        addChild(explosion)
        enemy.removeFromParent()
        
        damagePlayer(amount: 25)
        explosion.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.removeFromParent()]))
    }
    
    private func asteroidHitPlayer(player: SKSpriteNode, asteroid: SKSpriteNode) {
        let explosion = createExplosionEmitter(at: asteroid.position, color: .gray, size: asteroid.size)
        addChild(explosion)
        asteroid.removeFromParent()
        
        damagePlayer(amount: Int(asteroid.size.width / 3))
        explosion.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.removeFromParent()]))
    }
    
    private func damagePlayer(amount: Int) {
        playerHealth = max(0, playerHealth - amount)
        let healthPercent = CGFloat(playerHealth) / 100.0
        healthBar.xScale = healthPercent
        
        healthBar.color = healthPercent > 0.6 ? .green : healthPercent > 0.3 ? .yellow : .red
        
        playerShip.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.5, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1),
            SKAction.fadeAlpha(to: 0.5, duration: 0.1),
            SKAction.fadeAlpha(to: 1.0, duration: 0.1)
        ]))
        
        if playerHealth <= 0 {
            gameOver()
        }
    }
    
    private func gameOver() {
        isGameOver = true
        removeAction(forKey: "spawnEnemies")
        removeAction(forKey: "spawnAsteroids")
        
        let explosion = createExplosionEmitter(at: playerShip.position, color: .cyan, size: playerShip.size.scaled(by: 2))
        addChild(explosion)
        playerShip.removeFromParent()
        
        let gameOverLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        gameOverLabel.text = "GAME OVER"
        gameOverLabel.fontSize = 60
        gameOverLabel.fontColor = .red
        gameOverLabel.position = CGPoint(x: frame.midX, y: frame.midY)
        gameOverLabel.zPosition = 100
        gameOverLabel.setScale(0)
        addChild(gameOverLabel)
        
        gameOverLabel.run(SKAction.sequence([
            SKAction.scale(to: 1.0, duration: 0.5),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.5),
                SKAction.scale(to: 1.0, duration: 0.5)
            ]))
        ]))
        
        let finalScoreLabel = SKLabelNode(fontNamed: "Helvetica")
        finalScoreLabel.text = "Final Score: \(gameScore)"
        finalScoreLabel.fontSize = 30
        finalScoreLabel.fontColor = .white
        finalScoreLabel.position = CGPoint(x: frame.midX, y: frame.midY - 60)
        finalScoreLabel.zPosition = 100
        finalScoreLabel.alpha = 0
        addChild(finalScoreLabel)
        finalScoreLabel.run(SKAction.fadeIn(withDuration: 1.0))
        
        let restartLabel = SKLabelNode(fontNamed: "Helvetica")
        restartLabel.text = "Tap to Restart"
        restartLabel.fontSize = 25
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: frame.midX, y: frame.midY - 100)
        restartLabel.zPosition = 100
        restartLabel.alpha = 0
        addChild(restartLabel)
        restartLabel.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeIn(withDuration: 1.0),
            SKAction.repeatForever(SKAction.sequence([
                SKAction.fadeAlpha(to: 0.5, duration: 0.7),
                SKAction.fadeAlpha(to: 1.0, duration: 0.7)
            ]))
        ]))
        
        explosion.run(SKAction.sequence([SKAction.wait(forDuration: 2.0), SKAction.removeFromParent()]))
    }
    
    private func restartGame() {
        guard isGameOver else { return }
        
        // Remove all nodes except the starfield
        enumerateChildNodes(withName: "//*") { node, _ in
            if !(node.parent?.name == "starfield") {
                node.removeFromParent()
            }
        }
        
        // Reset game state
        gameScore = 0
        playerHealth = 100
        isGameOver = false
        lastUpdateTime = 0
        lastFireTime = 0
        lastEnemySpawnTime = 0
        
        // Reinitialize game elements
        setupPlayer()
        setupHUD()
        startSpawning()
    }
}

// MARK: - Helper Extensions

extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: x + dx, y: y + dy)
    }
}

extension CGSize {
    func scaled(by factor: CGFloat) -> CGSize {
        return CGSize(width: width * factor, height: height * factor)
    }
}
